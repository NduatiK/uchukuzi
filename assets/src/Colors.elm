module Colors exposing
    ( black
    , darkGreen
    , darkText
    , errorRed
    , fillDarkGreen
    , fillErrorRed
    , fillPurple
    , fillWhite
    , purple
    , semiDarkText
    , teal
    , white
    , withAlpha
    )

import Element exposing (..)
import Html.Attributes



-- COLORS


withAlpha : Color -> Float -> Color
withAlpha color alpha =
    let
        { red, green, blue } =
            toRgb color
    in
    rgba red green blue alpha


semiDarkText : Color
semiDarkText =
    withAlpha (rgb255 4 30 37) 0.69


black : Color
black =
    Element.rgb 0 0 0


white : Color
white =
    Element.rgb 1 1 1


purple : Color
purple =
    Element.rgb255 89 79 238


teal : Color
teal =
    Element.rgb255 102 218 213


darkGreen : Color
darkGreen =
    Element.rgb255 97 165 145


darkText : Color
darkText =
    Element.rgb255 4 31 38


errorRed : Color
errorRed =
    Element.rgb255 200 0 0


fillPurple : Attribute msg
fillPurple =
    Html.Attributes.style "filter" "brightness(0) saturate(100%) invert(24%) sepia(97%) saturate(1937%) hue-rotate(235deg) brightness(97%) contrast(93%)"
        |> htmlAttribute


fillWhite : Attribute msg
fillWhite =
    Html.Attributes.style "filter" "brightness(100%) saturate(0) invert(1)"
        |> htmlAttribute


fillDarkGreen : Attribute msg
fillDarkGreen =
    Html.Attributes.style "filter" "invert(59%) sepia(40%) saturate(342%) hue-rotate(114deg) brightness(93%) contrast(88%)"
        |> htmlAttribute


fillErrorRed : Attribute msg
fillErrorRed =
    Html.Attributes.style "filter" "invert(41%) sepia(141%) saturate(396%) hue-rotate(294deg) brightness(74%) contrast(121%)"
        |> htmlAttribute
