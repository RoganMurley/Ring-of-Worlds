module Replay.Types exposing (Model, Replay)

import PlayState.Types exposing (PlayState)


type alias Model =
    { replay : Maybe Replay
    }


type alias Replay =
    { state : PlayState
    , usernamePa : String
    , usernamePb : String
    , tick : Float
    }
