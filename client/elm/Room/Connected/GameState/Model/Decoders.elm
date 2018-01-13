module Model.Decoders exposing (..)

import Json.Decode as Json exposing (Decoder, fail, field, int, list, string, succeed)
import Card.Decoders as Card
import Model.Types exposing (..)


whichDecoder : Decoder WhichPlayer
whichDecoder =
    let
        decode : String -> Decoder WhichPlayer
        decode s =
            case s of
                "pa" ->
                    succeed PlayerA

                "pb" ->
                    succeed PlayerB

                otherwise ->
                    fail ("Invalid WhichPlayer " ++ s)
    in
        string |> Json.andThen decode


modelDecoder : Decoder Model
modelDecoder =
    Json.map6 (\a b c d e f -> Model a b c d e f Nothing)
        (field "handPA" <| list Card.decoder)
        (field "handPB" int)
        (field "stack" <| list stackCardDecoder)
        (field "turn" whichDecoder)
        (field "lifePA" int)
        (field "lifePB" int)


stackCardDecoder : Decoder StackCard
stackCardDecoder =
    Json.map2 StackCard
        (field "owner" whichDecoder)
        (field "card" Card.decoder)
