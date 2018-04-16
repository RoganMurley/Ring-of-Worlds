module GameCommand where

import Card (Card(..))
import CardAnim (CardAnim(..))
import Characters (CharModel(..), SelectedCharacters(..), selectChar, initCharModel)
import Control.Monad (replicateM_)
import Control.Monad.Free (foldFree)
import Control.Monad.Trans.Writer (Writer, runWriter, tell)
import Data.Maybe (fromMaybe)
import Data.Monoid ((<>))
import Data.String.Conversions (cs)
import Data.Text (Text)
import GameState (GameState(..), PlayState(..), initHandLength, initModel)
import Model (Hand, Passes(..), Model, Turn)
import ModelDiff (ModelDiff)
import Outcome (Outcome)
import Player (WhichPlayer(..), other)
import Safe (atMay, headMay, tailSafe)
import StackCard(StackCard(..))
import Username (Username)
import Util (Err, Gen, deleteIndex, split)


import qualified DSL.Alpha as Alpha
import qualified DSL.Beta as Beta
import qualified Outcome
import qualified Replay.Active as Active
import qualified Replay.Final as Final


data GameCommand =
    EndTurn
  | PlayCard Int
  | HoverCard (Maybe Int)
  | Rematch
  | Concede
  | SelectCharacter Text
  | Chat Username Text
  deriving (Show)


update :: GameCommand -> WhichPlayer -> GameState -> (Username, Username) -> Either Err (Maybe GameState, [Outcome])
update (Chat username msg) _ _ _ = chat username msg
update cmd which state usernames =
  case state of
    Waiting _ _ ->
      Left ("Unknown command " <> (cs $ show cmd) <> " on a waiting GameState")
    Selecting selectModel turn gen ->
      case cmd of
        SelectCharacter name ->
          select which name (selectModel, turn, gen) usernames
        _ ->
          Left ("Unknown command " <> (cs $ show cmd) <> " on a selecting GameState")
    Started started ->
      case started of
        Playing model replay ->
          case cmd of
            EndTurn ->
              endTurn which model replay
            PlayCard index ->
              playCard index which model replay
            HoverCard index ->
              hoverCard index which model
            Concede ->
              concede which state
            _ ->
              Left ("Unknown command " <> (cs $ show cmd) <> " on a Playing GameState")
        Ended winner _ _ gen ->
          case cmd of
            Rematch ->
              rematch (winner, gen)
            HoverCard _ ->
              ignore
            _ ->
              Left ("Unknown command " <> (cs $ show cmd) <> " on an Ended GameState")


ignore :: Either Err (Maybe GameState, [Outcome])
ignore = Right (Nothing, [])


rematch :: (Maybe WhichPlayer, Gen) -> Either Err (Maybe GameState, [Outcome])
rematch (winner, gen) =
  Right (
    Just $ Selecting initCharModel (fromMaybe PlayerA winner) (fst $ split gen)
  , [ Outcome.Sync ]
  )


chat :: Username -> Text -> Either Err (Maybe GameState, [Outcome])
chat username msg =
  Right (
    Nothing
  , [ Outcome.Encodable $ Outcome.Chat username msg ]
  )


concede :: WhichPlayer -> GameState -> Either Err (Maybe GameState, [Outcome])
concede which (Started (Playing model replay)) =
  let
    gen = Alpha.evalI model Alpha.getGen :: Gen
    anims = [(mempty, Just (GameEnd (Just (other which))), Nothing)]
    newReplay = Active.add replay anims :: Active.Replay
    newPlayState = Ended (Just (other which)) model newReplay gen :: PlayState
    finalReplay = Final.finalise newReplay newPlayState :: Final.Replay
  in
    Right (
      Just . Started $ newPlayState
    , [
        Outcome.Encodable $ Outcome.Resolve anims model newPlayState
      , Outcome.SaveReplay finalReplay
      ]
    )
concede _ _ =
  Left "Cannot concede when not playing"


select :: WhichPlayer -> Text -> (CharModel, Turn, Gen) -> (Username, Username) -> Either Err (Maybe GameState, [Outcome])
select which name (charModel, turn, gen) (usernamePa, usernamePb) =
  let
    newCharModel :: CharModel
    newCharModel = selectChar charModel which name
    result :: Maybe ([(ModelDiff, Maybe CardAnim, Maybe StackCard)], Model, PlayState)
    result =
      case newCharModel of
        (CharModel (ThreeSelected c1 c2 c3) (ThreeSelected ca cb cc) _) ->
          let
            model = initModel turn (c1, c2, c3) (ca, cb, cc) gen :: Model
            replay = Active.init model usernamePa usernamePb :: Active.Replay
            startProgram :: Beta.Program ()
            startProgram = do
                replicateM_ (initHandLength PlayerA turn) (Beta.draw PlayerA)
                replicateM_ (initHandLength PlayerB turn) (Beta.draw PlayerB)
            (newModel, _, anims) = Beta.execute model $ foldFree Beta.betaI startProgram
            res :: [(ModelDiff, Maybe CardAnim, Maybe StackCard)]
            res = (\(x, y) -> (x, y, Nothing)) <$> anims
            playstate :: PlayState
            playstate = Playing newModel (Active.add replay res)
          in
            Just (res, model, playstate)
        _ ->
          Nothing
    state :: GameState
    state =
      case result of
        Nothing ->
          Selecting newCharModel turn gen
        Just (_, _, playstate) ->
          Started playstate
    outcomes :: [Outcome]
    outcomes =
      case result of
        Nothing ->
          [ Outcome.Sync ]
        Just (res, model, playstate) ->
          [ Outcome.Encodable $ Outcome.Resolve res model playstate ]
  in
    Right (Just state, outcomes)


playCard :: Int -> WhichPlayer -> Model -> Active.Replay -> Either Err (Maybe GameState, [Outcome])
playCard index which m replay
  | turn /= which = Left "You can't play a card when it's not your turn"
  | otherwise     =
    case card of
      Nothing ->
        Left "You can't play a card you don't have in your hand"
      Just c ->
        let
          playCardProgram :: Beta.Program ()
          playCardProgram = do
            Beta.raw (do
              Alpha.swapTurn
              Alpha.resetPasses
              Alpha.modHand which (deleteIndex index))
            Beta.play which c
          (newModel, _, anims) = Beta.execute m $ foldFree Beta.betaI playCardProgram
          res :: [(ModelDiff, Maybe CardAnim, Maybe StackCard)]
          res = (\(x, y) -> (x, y, Nothing)) <$> anims
          newPlayState = Playing newModel (Active.add replay res) :: PlayState
        in
          Right (
            Just . Started $ newPlayState,
            [
              Outcome.Encodable $ Outcome.Resolve res m newPlayState
            ]
          )
  where
    (hand, turn, card) =
      Alpha.evalI m $ do
        h <- Alpha.getHand which
        t <- Alpha.getTurn
        let c = atMay hand index :: Maybe Card
        return (h, t, c)


endTurn :: WhichPlayer -> Model -> Active.Replay -> Either Err (Maybe GameState, [Outcome])
endTurn which model replay
  | turn /= which = Left "You can't end the turn when it's not your turn"
  | full          = Left "You can't end the turn when your hand is full"
  | otherwise     =
    case passes of
      OnePass ->
        case runWriter $ resolveAll model replay of
          (Playing m newReplay, res) ->
            let
              endProgram :: Beta.Program ()
              endProgram = do
                  Beta.raw Alpha.swapTurn
                  Beta.raw Alpha.resetPasses
                  drawCards
              (newModel, _, endAnims) = Beta.execute m $ foldFree Beta.betaI endProgram
              endRes :: [(ModelDiff, Maybe CardAnim, Maybe StackCard)]
              endRes = (\(x, y) -> (x, y, Nothing)) <$> endAnims
              newPlayState :: PlayState
              newPlayState = Playing newModel (Active.add newReplay endRes)
              newState = Started newPlayState :: GameState
            in
              Right (
                Just newState,
                [
                  Outcome.Encodable $ Outcome.Resolve (res ++ endRes) model newPlayState
                ]
              )
          (Ended w m newReplay g, res) ->
            let
              newPlayState = Ended w m newReplay g :: PlayState
              newState     = Started newPlayState  :: GameState
              finalReplay = Final.finalise newReplay newPlayState :: Final.Replay
            in
              Right (
                Just newState,
                [
                  Outcome.Encodable $ Outcome.Resolve res model newPlayState
                , Outcome.SaveReplay finalReplay
                ]
              )
      NoPass ->
        let
          newModel = Alpha.modI model Alpha.swapTurn :: Model
          newPlayState = Playing newModel replay :: PlayState
        in
          Right (
            Just . Started $ newPlayState,
            [
              Outcome.Encodable $ Outcome.Resolve [] model newPlayState
            ]
          )
  where
    (turn, passes) =
      Alpha.evalI model $ do
        t <- Alpha.getTurn
        p <- Alpha.getPasses
        return (t, p)
    full :: Bool
    full = Alpha.evalI model $ Alpha.handFull which
    drawCards :: Beta.Program ()
    drawCards = do
      Beta.draw PlayerA
      Beta.draw PlayerB


resolveAll :: Model -> Active.Replay -> Writer [(ModelDiff, Maybe CardAnim, Maybe StackCard)] PlayState
resolveAll model replay =
  case stackCard of
    Just c -> do
      let animsWithCard = (\(x, y) -> (x, y, Just c)) <$> anims
      tell animsWithCard
      case checkWin m (Active.add replay animsWithCard) of
        Playing m' newReplay ->
          resolveAll m' newReplay
        Ended w m' newReplay gen -> do
          let endAnim = [(mempty, Just (GameEnd w), Nothing)]
          tell endAnim
          return (Ended w m' (Active.add newReplay endAnim) gen)
    Nothing ->
      return (Playing model replay)
  where
    stackCard :: Maybe StackCard
    stackCard = Alpha.evalI model (headMay <$> Alpha.getStack)
    card :: Maybe (Beta.Program ())
    card = (\(StackCard o c) -> (card_eff c) o) <$> stackCard
    program :: Beta.AlphaLogAnimProgram ()
    program = case card of
      Just p ->
        foldFree Beta.betaI $ do
          Beta.raw $ Alpha.modStack tailSafe
          p
      Nothing ->
        return ()
    (m, _, anims) = Beta.execute model program :: (Model, String, [(ModelDiff, Maybe CardAnim)])



checkWin :: Model -> Active.Replay -> PlayState
checkWin m r
  | lifePA <= 0 && lifePB <= 0 =
    Ended Nothing m r gen
  | lifePB <= 0 =
    Ended (Just PlayerA) m r gen
  | lifePA <= 0 =
    Ended (Just PlayerB) m r gen
  | otherwise =
    Playing m r
  where
    (gen, lifePA, lifePB) =
      Alpha.evalI m $ do
        g  <- Alpha.getGen
        la <- Alpha.getLife PlayerA
        lb <- Alpha.getLife PlayerB
        return (g, la, lb)


hoverCard :: Maybe Int -> WhichPlayer -> Model -> Either Err (Maybe GameState, [Outcome])
hoverCard (Just i) which model
  | i >= (length (Alpha.evalI model $ Alpha.getHand which :: Hand) :: Int) =
    Left ("Hover index out of bounds (" <> (cs . show $ i ) <> ")" :: Err)
  | otherwise =
    Right (Nothing, [ Outcome.Encodable $ Outcome.Hover which (Just i) ])
hoverCard Nothing which _ =
  Right (Nothing, [ Outcome.Encodable $ Outcome.Hover which Nothing ])
