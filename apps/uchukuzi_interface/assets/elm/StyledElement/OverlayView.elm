module StyledElement.OverlayView exposing (view)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Input as Input
import Style


view :
    { shouldShowOverlay : Bool
    , hideOverlayMsg : msg
    , height : Length
    }
    -> (() -> Element msg)
    -> Element msg
view { shouldShowOverlay, hideOverlayMsg, height } overlayView =
    el
        (Style.animatesAll
            :: width fill
            :: Element.height fill
            :: behindContent
                (Input.button
                    [ width fill
                    , Element.height fill
                    , Background.color (Colors.withAlpha Colors.black 0.6)
                    , Style.blurredStyle
                    , if shouldShowOverlay then
                        Style.nonClickThrough

                      else
                        Style.clickThrough
                    ]
                    { onPress = Just hideOverlayMsg
                    , label = none
                    }
                )
            :: (if shouldShowOverlay then
                    [ alpha 1, Style.nonClickThrough ]

                else
                    [ alpha 0, Style.clickThrough ]
               )
        )
        (if shouldShowOverlay then
            el [ Element.height height, scrollbarY, width fill, paddingXY 40 30 ] (overlayView ())

         else
            none
        )
