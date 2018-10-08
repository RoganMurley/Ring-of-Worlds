module Animation.State exposing (..)

import Animation.Types exposing (Anim(..))
import Ease


animShake : Anim -> Float -> Float
animShake anim tick =
    let
        baseMag =
            case anim of
                Slash _ d ->
                    5.0 * Ease.outQuad (toFloat d / 50.0)

                Bite _ d ->
                    5.0 * Ease.outQuad (toFloat d / 50.0)

                Obliterate _ ->
                    20.0

                Play _ _ _ ->
                    1.0

                _ ->
                    0.0

        mag =
            baseMag * (1.0 - Ease.outQuad (tick / animMaxTick anim))
    in
        mag * 0.03 * (toFloat <| (ceiling tick * 1247823748932 + 142131) % 20) - 10


animMaxTick : Anim -> Float
animMaxTick anim =
    case anim of
        Draw _ ->
            500.0

        Reverse _ ->
            1500.0

        Play _ _ _ ->
            500.0

        Overdraw _ _ ->
            1000.0

        Obliterate _ ->
            1000.0

        GameEnd _ ->
            2500.0

        Rotate _ ->
            1000.0

        Windup _ ->
            300.0

        _ ->
            800.0


progress : Anim -> Float -> Float
progress anim tick =
    let
        maxTick : Float
        maxTick =
            animMaxTick anim

        easingFunction : Float -> Float
        easingFunction =
            case anim of
                Heal _ ->
                    Ease.outQuad

                Overdraw _ _ ->
                    Ease.outQuint

                Rotate _ ->
                    Ease.inQuad

                Slash _ _ ->
                    Ease.outQuad

                Windup _ ->
                    Ease.inQuad

                _ ->
                    Ease.outQuint
    in
        easingFunction (tick / maxTick)
