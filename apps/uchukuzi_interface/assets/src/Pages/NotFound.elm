module Pages.NotFound exposing (view)

import Element exposing (..)
import Element.Font as Font
import Style


view : Element msg
view =
    row [ width fill, height fill, spaceEvenly ]
        [ el [ width (fillPortion 1) ] none
        , view404
        , el [ width (fillPortion 1) ] none
        ]


view404 =
    el [ width (fillPortion 8), centerX, centerY, Font.size 100, Font.center, Font.heavy, alpha 0.4 ] (text "404")
