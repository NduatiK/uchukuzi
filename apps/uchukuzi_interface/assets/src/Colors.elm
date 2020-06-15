module Colors exposing (..)

{-| This module provides a color palette
-}
import Color
import Element exposing (..)
import Element.Background as Background
import Html.Attributes



-- COLORS


svgColorwithAlpha : Float -> Color.Color -> Color.Color
svgColorwithAlpha alpha color =
    let
        { red, green, blue } =
            Color.toRgba color
    in
    Color.rgba red green blue alpha


toSVGColor : Color -> Color.Color
toSVGColor color =
    let
        { red, green, blue } =
            toRgb color
    in
    Color.rgb red green blue


withGradient : Float -> Color -> Attr decorative msg
withGradient radius color =
    Background.gradient
        { angle = radius
        , steps = [ color, withAlpha color 0, withAlpha color 0 ]
        }


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


transparent : Color
transparent =
    Element.rgba 0 0 0 0


backgroundGray : Color
backgroundGray =
    rgb255 245 246 248


black : Color
black =
    Element.rgb 0 0 0


white : Color
white =
    Element.rgb 1 1 1

{-| Use this color for clickable highlights
-}
purple : Color
purple =
    Element.rgb255 89 79 238


backgroundPurple : Color
backgroundPurple =
    Element.rgb255 222 220 252


lightGrey : Color
lightGrey =
    Element.rgb255 244 244 244


simpleGrey : Color
simpleGrey =
    Element.rgb255 224 224 224


sassyGrey : Color
sassyGrey =
    Element.rgb255 163 175 190


sassyGreyDark : Color
sassyGreyDark =
    Element.rgb255 130 140 152


teal : Color
teal =
    Element.rgb255 102 218 213


darkGreen : Color
darkGreen =
    Element.rgb255 30 165 145


backgroundGreen : Color
backgroundGreen =
    Element.rgba255 30 165 145 0.7


darkText : Color
darkText =
    Element.rgb255 4 31 38


darkness : Color
darkness =
    Element.rgb255 51 63 78


semiDarkness : Color
semiDarkness =
    rgb255 115 115 115


errorRed : Color
errorRed =
    Element.rgb255 200 0 0


-- ICON COLORS
{-| Icons ignore the standard colors. 
These attributes paint into images using filters

Have a look at 
-}

fillPurple : Attribute msg
fillPurple =
    class "fillPurple"


fillWhite : Attribute msg
fillWhite =
    class "fillWhite"


fillDarkGreen : Attribute msg
fillDarkGreen =
    class "fillDarkGreen"


fillDarkness : Attribute msg
fillDarkness =
    class "fillDarkness"


fillErrorRed : Attribute msg
fillErrorRed =
    class "fillErrorRed"


fillErrorRedHover : Attribute msg
fillErrorRedHover =
    class "fillErrorRedOnHover"


fillWhiteOnHover : Attribute msg
fillWhiteOnHover =
    class "fillWhiteOnHover"


class : String -> Attribute msg
class string =
    htmlAttribute (Html.Attributes.class string)
