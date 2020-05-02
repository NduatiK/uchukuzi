module Pages.NotFound exposing (view)

import Colors
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
    el
        [ width (fillPortion 8)
        , centerX
        , centerY
        , Font.size 220
        , Font.center
        , Font.bold
        , Font.color (Colors.withAlpha Colors.simpleGrey 0.4)
        , inFront
            (paragraph
                [ centerY
                , centerX
                , Font.size 80
                , Font.medium
                , Font.color (Colors.withAlpha Colors.darkness 0.5)
                , Font.italic
                ]
                [ text "Page Not Found" ]
             -- [ text "That page does not exists" ]
            )
        ]
        -- (text "404\u{1F926}\u{1F3FE}\u{200D}♂️")
        (text "404")
