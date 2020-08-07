module DeckBuilding.View exposing (webglView)

import Assets.Types as Assets
import Background.View exposing (radialView)
import DeckBuilding.Messages exposing (Msg(..))
import DeckBuilding.Types exposing (Model)
import Font.Types as Font
import Font.View as Font
import Game.State exposing (bareContextInit)
import Game.Types exposing (Context)
import Math.Vector3 exposing (vec3)
import Render.Types as Render
import RuneSelect.Types as RuneSelect exposing (RuneCursor(..))
import RuneSelect.View as RuneSelect
import WebGL
import WebGL.Texture as WebGL
import WhichPlayer.Types exposing (WhichPlayer(..))


webglView : Render.Params -> Model -> Assets.Model -> List WebGL.Entity
webglView { w, h } model assets =
    let
        ctx =
            bareContextInit ( w, h ) assets Nothing
    in
    List.concat <|
        List.map ((|>) ctx) <|
            case model.runeSelect of
                Just runeSelect ->
                    [ RuneSelect.webglView runeSelect ]

                Nothing ->
                    [ radialView model.vfx
                    , titleView model.vfx.rotation
                    ]


titleView : Float -> Context -> List WebGL.Entity
titleView tick ({ w, h } as ctx) =
    let
        size =
            1.4 * max w h
    in
    List.concat
        [ Font.view
            "Futura"
            "GALGAGAME"
            { x = w * 0.5 - 0.003 * size
            , y = h * 0.5
            , scaleX = 0.0001 * size + 0.003 * sin (tick * 0.005)
            , scaleY = 0.0001 * size + 0.003 * sin (tick * 0.007)
            , color = vec3 (20 / 255) (20 / 255) (20 / 255)
            }
            ctx
        , Font.view
            "Futura"
            "GALGAGAME"
            { x = w * 0.5
            , y = h * 0.5
            , scaleX = 0.0001 * size + 0.003 * sin (tick * 0.005)
            , scaleY = 0.0001 * size + 0.003 * sin (tick * 0.007)
            , color = vec3 (244 / 255) (241 / 255) (94 / 255)
            }
            ctx
        ]
