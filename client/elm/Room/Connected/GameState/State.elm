module GameState.State exposing (update, tick, tickZero, resolvable, resMapPlay)

import Audio exposing (playSound)
import CharacterSelect.State as CharacterSelect
import GameState.Decoders exposing (playStateDecoder, stateDecoder)
import GameState.Encoders exposing (encodeHoverIndex)
import GameState.Messages exposing (..)
import GameState.Types exposing (GameState(..), PlayState(..))
import Json.Decode as Json exposing (field, maybe)
import Main.Messages as Main
import Main.Types exposing (Flags)
import Mode as Mode
import Model.Decoders as Model
import Model.Types exposing (..)
import Navigation
import Ports exposing (reload)
import Resolvable.Decoders exposing (resolveDiffDataDecoder)
import Resolvable.State as Resolvable
import Resolvable.Types as Resolvable
import Model.ViewModel
import Util exposing (message, safeTail, send, unsafeForceDecode)
import WhichPlayer.Types exposing (WhichPlayer(..))


update : Msg -> GameState -> Mode.Mode -> Flags -> ( GameState, Cmd Main.Msg )
update msg state mode flags =
    case msg of
        Sync str ->
            ( syncState state str, Cmd.none )

        HoverSelf i ->
            case state of
                Started (Playing ({ vm } as m)) ->
                    let
                        newVm : Model.ViewModel.ViewModel
                        newVm =
                            { vm | hover = i }
                    in
                        ( Started <| Playing { m | vm = newVm }
                        , Cmd.none
                        )

                s ->
                    ( s, Cmd.none )

        HoverOutcome i ->
            case state of
                Started (Playing ({ final } as m)) ->
                    let
                        newFinal : Model
                        newFinal =
                            { final | otherHover = i }
                    in
                        ( Started <| Playing { m | final = newFinal }
                        , Cmd.none
                        )

                s ->
                    ( s, Cmd.none )

        ResolveOutcome str ->
            let
                oldResList : List Resolvable.ResolveData
                oldResList =
                    case state of
                        Started playState ->
                            .resList <| resolvable playState

                        otherwise ->
                            []

                oldTick : Float
                oldTick =
                    case ( state, oldResList ) of
                        ( Started playState, [] ) ->
                            0

                        ( Started playState, _ ) ->
                            .tick <| resolvable playState

                        otherwise ->
                            0

                initial : Model
                initial =
                    unsafeForceDecode ((Json.field "initial") Model.decoder) str

                resDiffList : List Resolvable.ResolveDiffData
                resDiffList =
                    unsafeForceDecode ((Json.field "list") (Json.list resolveDiffDataDecoder)) str

                resList : List Resolvable.ResolveData
                resList =
                    Resolvable.resDiffToData initial resDiffList

                finalState : PlayState
                finalState =
                    unsafeForceDecode ((Json.field "final") playStateDecoder) str

                model : Model
                model =
                    .final <| resolvable finalState

                res : Resolvable.Model
                res =
                    { vm = Model.ViewModel.init
                    , tick = oldTick
                    , final = model
                    , resList = oldResList ++ resList
                    }

                newState : GameState
                newState =
                    carryVm state <|
                        resMap
                            (\_ -> res)
                            (Started finalState)
            in
                ( newState, Cmd.none )

        ReplaySaved replayId ->
            case state of
                Started (Ended winner res _) ->
                    ( Started (Ended winner res (Just replayId)), Cmd.none )

                otherwise ->
                    ( state, Cmd.none )

        SelectingMsg selectMsg ->
            case state of
                Selecting m ->
                    let
                        ( newModel, cmd ) =
                            CharacterSelect.update selectMsg m
                    in
                        ( Selecting newModel, cmd )

                otherwise ->
                    Debug.log
                        "Expected a selecting state"
                        ( state, Cmd.none )

        PlayingOnly playingOnly ->
            updatePlayingOnly playingOnly state mode flags

        GotoReplay replayId ->
            ( state
            , Cmd.batch
                [ Navigation.newUrl <| "/replay/" ++ replayId
                , reload ()
                ]
            )


updatePlayingOnly : PlayingOnly -> GameState -> Mode.Mode -> Flags -> ( GameState, Cmd Main.Msg )
updatePlayingOnly msg state mode flags =
    let
        legal =
            case mode of
                Mode.Playing ->
                    True

                Mode.Spectating ->
                    False
    in
        if not legal then
            ( state, Cmd.none )
        else
            case msg of
                Rematch ->
                    case state of
                        Started (Ended _ _ _) ->
                            ( state, send flags "rematch:" )

                        otherwise ->
                            ( state, Cmd.none )

                HoverCard mIndex ->
                    let
                        ( newState, cmd ) =
                            update (HoverSelf mIndex) state mode flags

                        sound =
                            case mIndex of
                                Nothing ->
                                    Cmd.none

                                otherwise ->
                                    playSound "/sfx/hover.wav"
                    in
                        ( newState
                        , Cmd.batch
                            [ cmd
                            , message <|
                                Main.Send <|
                                    "hover:"
                                        ++ (encodeHoverIndex mIndex)
                            , sound
                            ]
                        )

                TurnOnly turnOnly ->
                    updateTurnOnly turnOnly state mode flags


updateTurnOnly : TurnOnly -> GameState -> Mode.Mode -> Flags -> ( GameState, Cmd Main.Msg )
updateTurnOnly msg state mode flags =
    let
        legal =
            case state of
                Started (Playing { final }) ->
                    final.turn == PlayerA

                otherwise ->
                    False
    in
        if not legal then
            ( state, Cmd.none )
        else
            case msg of
                EndTurn ->
                    ( state
                    , Cmd.batch
                        [ send flags "end:"
                        , playSound "/sfx/endTurn.wav"
                        ]
                    )

                PlayCard index ->
                    let
                        ( newState, cmd ) =
                            update (HoverSelf Nothing) state mode flags
                    in
                        ( newState
                        , Cmd.batch
                            [ send flags ("play:" ++ (toString index))
                            , playSound "/sfx/playCard.wav"
                            , cmd
                            ]
                        )


syncState : GameState -> String -> GameState
syncState oldState msg =
    case Json.decodeString stateDecoder msg of
        Ok newState ->
            carryVm oldState newState

        Err err ->
            Debug.log
                err
                oldState


carryVm : GameState -> GameState -> GameState
carryVm old new =
    case old of
        Selecting { vm } ->
            case new of
                Selecting selecting ->
                    Selecting { selecting | vm = vm }

                otherwise ->
                    new

        Started oldStarted ->
            case new of
                Started newStarted ->
                    let
                        oldVm : Model.ViewModel.ViewModel
                        oldVm =
                            .vm <| resolvable oldStarted
                    in
                        Started <|
                            resMapPlay (\r -> { r | vm = oldVm }) newStarted

                otherwise ->
                    new

        otherwise ->
            new


resMap : (Resolvable.Model -> Resolvable.Model) -> GameState -> GameState
resMap f state =
    case state of
        Started started ->
            Started <| resMapPlay f started

        otherwise ->
            state


resMapPlay : (Resolvable.Model -> Resolvable.Model) -> PlayState -> PlayState
resMapPlay f started =
    resolvableSet started <|
        f (resolvable started)


resolvableSet : PlayState -> Resolvable.Model -> PlayState
resolvableSet s r =
    case s of
        Playing _ ->
            Playing r

        Ended w _ replay ->
            Ended w r replay


tick : GameState -> Float -> GameState
tick state dt =
    resMap (Resolvable.tick dt) state


tickZero : PlayState -> Bool
tickZero started =
    let
        res =
            resolvable started
    in
        Resolvable.tickZero res.tick (Resolvable.activeAnim res)


resolvable : PlayState -> Resolvable.Model
resolvable state =
    case state of
        Playing r ->
            r

        Ended _ r _ ->
            r
