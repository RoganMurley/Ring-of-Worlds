module Card.Types exposing (Card, CardCol(..), Entity)

import Game.Entity as Game
import WhichPlayer.Types exposing (WhichPlayer)


type alias Card =
    { name : String
    , desc : String
    , imgURL : String
    , col : CardCol
    }


type CardCol
    = Red
    | Orange
    | Yellow
    | Green
    | Blue
    | Indigo
    | Violet
    | Mystery


type alias Entity a =
    Game.Entity
        { a
            | card : Card
            , owner : WhichPlayer
        }
