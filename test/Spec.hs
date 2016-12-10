import Test.Tasty
import Test.Tasty.HUnit

import Cards
import Model
import GameState
import Util


-- Helpers.
isEq :: (Eq a, Show a) => a -> a -> Assertion
isEq = assertEqual ""

isTrue :: Bool -> Assertion
isTrue = assertBool ""

isFalse :: Bool -> Assertion
isFalse = (assertBool "") . not

fromRight :: Either a b -> b
fromRight (Right r) = r
fromRight _ = error "Illegal from right!"


resolveState :: GameState -> GameState
resolveState (Playing model) = resolveAll model
resolveState s = s

-- fromPlaying
fP :: Either Err GameState -> Model
fP (Right (Playing model)) = model
fP _               = error "Looks like that state's not a Playing, kid!"


-- Tests.
main :: IO ()
main = defaultMain $
  testGroup "Unit Tests"
    [
      initModelTests
    , cardTests
    , turnEndTests
    ]


initModelTests :: TestTree
initModelTests =
  testGroup "Initial Model"
    [
      testCase "PlayerA has 50 life" $
        isEq (getLife PlayerA model) 50

    , testCase "PlayerB has 50 life" $
        isEq (getLife PlayerB model) 50
    ]
  where
    model = initModel PlayerA (mkGen 0)


cardTests :: TestTree
cardTests =
  testGroup "Cards"
    [
      cardDaggerTests
    , cardHubrisTests
    , cardFireballTests
    , cardBoomerangTests
    , cardPotionTests
    , cardVampireTests
    , cardSuccubusTests
    ]


cardDummy :: Card
cardDummy =
  Card "Dummy" "Does nothing, just for testing" "" (\_ _ m -> m)


cardDaggerTests :: TestTree
cardDaggerTests =
  testGroup "Dagger Card"
    [
      testCase "Should hurt for 8" $
        case resolveState state of
          Playing model -> do
            isEq maxLife       (getLife PlayerA model)
            isEq (maxLife - 8) (getLife PlayerB model)
          _ ->
            assertFailure "Incorrect state"
    ]
  where
    state =
      Playing $
        (initModel PlayerA (mkGen 0))
          { stack = [StackCard PlayerA cardDagger] }


cardHubrisTests :: TestTree
cardHubrisTests =
  testGroup "Hubris Card"
    [
      testCase "Should negate everything to the right" $
        case resolveState state of
          Playing model -> do
            isEq maxLife (getLife PlayerA model)
            isEq maxLife (getLife PlayerB model)
          _ ->
            assertFailure "Incorrect state"
    ]
  where
    state =
      Playing $
        (initModel PlayerA (mkGen 0))
          { stack = [
            StackCard PlayerB cardHubris
          , StackCard PlayerA cardFireball
          , StackCard PlayerB cardFireball
          , StackCard PlayerB cardDummy
          , StackCard PlayerB cardDummy
          ] }


cardFireballTests :: TestTree
cardFireballTests =
  testGroup "Fireball Card"
    [
      testCase "Should hurt for 4 for everything to the right" $
        case resolveState state of
          Playing model -> do
            isEq maxLife        (getLife PlayerA model)
            isEq (maxLife - 16) (getLife PlayerB model)
          _ ->
            assertFailure "Incorrect state"
    ]
  where
    state =
      Playing $
        (initModel PlayerA (mkGen 0))
          { stack = [
            StackCard PlayerA cardFireball
          , StackCard PlayerA cardDummy
          , StackCard PlayerB cardDummy
          , StackCard PlayerB cardDummy
          , StackCard PlayerB cardDummy
          ] }

cardBoomerangTests :: TestTree
cardBoomerangTests =
  testGroup "Boomerang Card"
    [
      testCase "Should hurt for 2" $
        case resolveState state of
          Playing model -> do
            isEq maxLife        (getLife PlayerA model)
            isEq (maxLife - 2)  (getLife PlayerB model)
          _ ->
            assertFailure "Incorrect state"
    , testCase "Comes back to hand" $
        case resolveState state of
          Playing model ->
            let hand = getHand PlayerA model in
              isTrue (elem cardBoomerang hand)
          _ ->
            assertFailure "Incorrect state"
    , testCase "Doesn't come back to hand if hand is full" $
        case resolveState (fullHandState) of
          Playing model ->
            let hand = getHand PlayerA model in
              isFalse (elem cardBoomerang hand)
          _ ->
            assertFailure "Incorrect state"
    ]
  where
    state =
      Playing $
        (initModel PlayerA (mkGen 0))
          { stack = [
            StackCard PlayerA cardBoomerang
          ] }
    fullHandState =
      Playing . (setHand PlayerA (replicate 6 cardDummy)) . fP $ Right state


cardPotionTests :: TestTree
cardPotionTests =
  testGroup "Potion Card"
    [
      testCase "Should heal for 7" $
        case resolveState stateHalfLife of
          Playing model -> do
            isEq (halfLife + 7) (getLife PlayerA model)
            isEq maxLife        (getLife PlayerB model)
          _ ->
            assertFailure "Incorrect state"
    , testCase "No overheal" $
        case resolveState state of
          Playing model -> do
            isEq maxLife (getLife PlayerA model)
            isEq maxLife (getLife PlayerB model)
          _ ->
            assertFailure "Incorrect state"
    ]
  where
    state = Playing $
      (initModel PlayerA (mkGen 0))
        { stack = [
          StackCard PlayerA cardPotion
        ] }
    halfLife = maxLife `div` 2 :: Life
    stateHalfLife =
      Playing . (setLife PlayerA halfLife) . fP $ Right state


cardVampireTests :: TestTree
cardVampireTests =
  testGroup "Vampire Card"
    [
      testCase "Should lifesteal for 5" $
        case resolveState stateHalfLife of
          Playing model -> do
            isEq (halfLife + 5) (getLife PlayerA model)
            isEq (maxLife  - 5) (getLife PlayerB model)
          _ ->
            assertFailure "Incorrect state"
    , testCase "No overheal" $
        case resolveState state of
          Playing model -> do
            isEq maxLife       (getLife PlayerA model)
            isEq (maxLife - 5) (getLife PlayerB model)
          _ ->
            assertFailure "Incorrect state"
    ]
  where
    state = Playing $
      (initModel PlayerA (mkGen 0))
        { stack = [
          StackCard PlayerA cardVampire
        ] }
    halfLife = maxLife `div` 2 :: Life
    stateHalfLife =
      Playing . (setLife PlayerA halfLife) . fP $ Right state


cardSuccubusTests :: TestTree
cardSuccubusTests =
  testGroup "Succubus Card"
    [
      testCase "Should lifesteal for 2 for everything to the right" $
        case resolveState stateHalfLife of
          Playing model -> do
            isEq (halfLife + 8) (getLife PlayerA model)
            isEq (maxLife  - 8) (getLife PlayerB model)
          _ ->
            assertFailure "Incorrect state"
    , testCase "No overheal" $
        case resolveState state of
          Playing model -> do
            isEq maxLife       (getLife PlayerA model)
            isEq (maxLife - 8) (getLife PlayerB model)
          _ ->
            assertFailure "Incorrect state"
    ]
  where
    state =
      Playing $
        (initModel PlayerA (mkGen 0))
          { stack = [
            StackCard PlayerA cardSuccubus
          , StackCard PlayerA cardDummy
          , StackCard PlayerB cardDummy
          , StackCard PlayerB cardDummy
          , StackCard PlayerB cardDummy
          ] }
    halfLife = maxLife `div` 2 :: Life
    stateHalfLife =
      Playing . (setLife PlayerA halfLife) . fP $ Right state


turnEndTests :: TestTree
turnEndTests =
  testGroup "Turn end tests"
    [
      testCase "Ending the turn when it's not your turn does nothing" $
        isEq
          (Right state)
          (update EndTurn PlayerB state)
    , testCase "Ending the turn when your hand is full does nothing" $
        isEq
          (Right fullHandState)
          (update EndTurn PlayerA fullHandState)
    , testCase "Ending the turn swaps the turn player" $
        isEq
          PlayerB
          (turn . fP $ update EndTurn PlayerA state)
    , testCase "Ending the turn increments the passes count" $
        isEq
          OnePass
          (passes . fP $ update EndTurn PlayerA state)
    , testCase "Ending the turn twice resets the passes count" $
        isEq
          NoPass
          (passes . fP $ endTwice)
    , testCase "Ending the turn twice draws a card for PlayerA" $
        isEq
          ((length . (getHand PlayerA) . fP $ Right state) + 1)
          (length . (getHand PlayerA) . fP $ endTwice)
    , testCase "Ending the turn twice draws a card for PlayerB" $
        isEq
          ((length . (getHand PlayerB) . fP $ Right state) + 1)
          (length . (getHand PlayerB) . fP $ endTwice)
    ]
  where
    state = Playing (initModel PlayerA (mkGen 0))
    fullHandState = Playing . (drawCard PlayerA) . (drawCard PlayerA) $ initModel PlayerA (mkGen 0)
    endTwice = (update EndTurn PlayerB) . fromRight . (update EndTurn PlayerA) $ state
