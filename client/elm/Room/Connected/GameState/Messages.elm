module GameState.Messages exposing (Msg(..))

import DeckBuilding.Messages as DeckBuilding
import Mouse
import PlayState.Messages as PlayState


type Msg
    = PlayStateMsg PlayState.Msg
    | ResolveOutcome String
    | SelectingMsg DeckBuilding.Msg
    | Sync String
    | MouseDown Mouse.Position
    | MouseUp Mouse.Position
