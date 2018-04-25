module Clock.State exposing (..)

import Clock.Types exposing (Model, Uniforms)
import Ease
import Math.Matrix4 exposing (Mat4, identity, makeLookAt, makePerspective, makeRotate, makeScale3, mul)
import Math.Vector2 exposing (vec2)
import Math.Vector3 exposing (Vec3, vec3)
import Raymarch.Types exposing (Height, Width)
import WebGL exposing (Texture)


init : Model
init =
    { time = 0.0
    , turns = 0
    }


maxTick : Float
maxTick =
    800


tick : Model -> Float -> Model
tick ({ time, turns } as model) dt =
    let
        ( newTime, newTurns ) =
            if time < maxTick then
                ( time + dt, turns )
            else
                ( 0, turns + 1 )
    in
        { model | time = newTime, turns = newTurns }


uniforms : Float -> ( Width, Height ) -> Texture -> Vec3 -> Mat4 -> Uniforms
uniforms t ( width, height ) texture pos rot =
    { resolution = vec2 (toFloat width) (toFloat height)
    , texture = texture
    , rotation = rot
    , scale = makeScale3 0.2 0.2 1
    , worldPos = pos
    , worldRot = makeRotate 0 (vec3 0 0 1)
    , perspective = makePerspective 45 ((toFloat width) / (toFloat height)) 0.01 100
    , camera = makeLookAt (vec3 0 0 2) (vec3 0 0 0) (vec3 0 1 0)
    }


clockFace : Int -> Vec3 -> Float -> Float -> List ( Vec3, Mat4 )
clockFace n origin radius time =
    let
        indexes : List Int
        indexes =
            List.range 0 (n - 1)

        genPoint : Int -> ( Vec3, Mat4 )
        genPoint i =
            ( Math.Vector3.add origin (offset i), rotation i )

        segmentAngle : Float
        segmentAngle =
            2.0 * pi / (toFloat n)

        progress : Float
        progress =
            Ease.inQuad <| time / maxTick

        rot : Int -> Float
        rot i =
            (toFloat i)
                * segmentAngle
                + progress
                * segmentAngle

        offset : Int -> Vec3
        offset i =
            Math.Vector3.scale radius <|
                vec3 (sin (rot i)) (cos (rot i)) 0

        rotation : Int -> Mat4
        rotation i =
            makeRotate (2 * pi - (rot i)) (vec3 0 0 1)
    in
        List.map genPoint indexes