module Outcome where

import Data.Aeson (ToJSON(..), (.=), object)
import Data.Text (Text)

import GameState (PlayState)
import Model (CardAnim, Model, StackCard)
import Player (WhichPlayer)
import Username (Username)


type ExcludePlayer = WhichPlayer


data Outcome =
    Sync
  | Encodable Encodable
  deriving (Eq, Show)


data Encodable =
    Chat Username Text
  | Hover ExcludePlayer (Maybe Int)
  | Resolve [(Model, Maybe CardAnim, Maybe StackCard)] PlayState
  deriving (Eq, Show)


instance ToJSON Encodable where
  toJSON (Chat name msg) =
    object [
      "name" .= name
    , "msg"  .= msg
    ]
  toJSON (Hover _ index) =
    toJSON index
  toJSON (Resolve res state) =
    object [
      "list"  .= res
    , "final" .= state
    ]
