module Pages.ErrorPage exposing (..)

import Browser
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Html
import Html.Attributes exposing (src)
import Icons
import Style


view : Element msg
view =
    let
        renderTextRow content =
            paragraph [ centerX, Font.center ]
                [ el
                    [ Background.color Colors.white
                    , width shrink
                    , paddingXY 16 4
                    , behindContent (el [ Background.color (Colors.withAlpha Colors.darkGreen 0.7), width fill, height fill ] none)
                    ]
                    (text content)
                ]

        renderedView =
            el
                [ width (fillPortion 8)
                , centerX
                , centerY
                , Font.size 220
                , Font.center
                , Font.bold
                , Font.color (Colors.withAlpha Colors.simpleGrey 0.3)
                , inFront
                    (textColumn
                        (Style.labelStyle
                            ++ [ centerX
                               , centerY
                               , Font.regular
                               , Font.size 24
                               , spacing 20
                               ]
                        )
                        [ renderTextRow "Something went wrong"
                        , renderTextRow "Are you online?"
                        ]
                    )
                ]
                (text "Oops!")
    in
    renderedView
