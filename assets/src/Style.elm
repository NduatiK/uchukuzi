module Style exposing
    ( animatesAll
    , animatesAll20Seconds
    , animatesAllDelayed
    , animatesShadow
    , blurredStyle
    , borderedContainer
    , captionLabelStyle
    , clipStyle
    , cssResponsive
    , darkGreenColor
    , darkTextColor
    , edges
    , errorColor
    , fillColor
    , fillColorDarkGreen
    , fillColorPurple
    , fillColorWhite
    , header2Style
    , headerStyle
    , inputStyle
    , labelFontStyle
    , labelStyle
    , mobileHidden
    , purpleColor
    , stickyStyle
    , tableElementStyle
    , tableHeaderStyle
    , tealColor
    , textFontStyle
    , withAlpha
    )

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Hex
import Html.Attributes
import Route



-- STYLES


borderedContainer : List (Attribute msg)
borderedContainer =
    [ Border.width 1
    , Border.color (rgb255 163 175 190)
    ]


headerStyle : List (Attribute msg)
headerStyle =
    [ Region.heading 1
    , Font.size 31
    , Font.family
        [ Font.typeface "SF Pro Display"

        --  Font.typeface "InterUI-Bold"
        , Font.sansSerif
        ]
    , paddingXY 0 10
    , Font.bold
    ]


header2Style : List (Attribute msg)
header2Style =
    [ Region.heading 2
    , Font.size 24
    , Font.color (rgb255 51 63 78)
    , Font.family
        [ Font.typeface "SF Pro Display"

        --  Font.typeface "InterUI-Bold"
        , Font.sansSerif
        ]
    , Font.bold
    , paddingXY 0 10
    ]


captionLabelStyle : List (Attribute msg)
captionLabelStyle =
    [ Font.size 13
    , Font.color (rgb255 4 30 37)
    , alpha 0.69
    ]
        ++ labelFontStyle


labelStyle : List (Attribute msg)
labelStyle =
    [ Font.size 15
    , Font.color (rgb255 51 63 78)
    ]
        ++ labelFontStyle


inputStyle : List (Attribute msg)
inputStyle =
    [ Background.color (rgb255 245 245 245)
    , Border.color darkGreenColor
    , Border.widthEach
        { bottom = 2
        , left = 0
        , right = 0
        , top = 0
        }
    , Border.solid
    , Font.size 16
    , height
        (fill
            |> minimum 46
        )
    ]
        ++ textFontStyle


tableHeaderStyle : List (Attribute msg)
tableHeaderStyle =
    [ Region.heading 4
    , Font.size 14
    , Font.color (rgb255 115 115 115)
    , Font.letterSpacing 0.58
    , Font.bold
    , alignLeft
    ]
        ++ textFontStyle


tableElementStyle : List (Attribute msg)
tableElementStyle =
    [ Region.heading 4
    , Font.size 18
    , Font.color (rgb255 96 96 96)
    , alignLeft
    ]
        ++ textFontStyle


{-| Sets Font.family to custom font
-}
textFontStyle : List (Attribute msg)
textFontStyle =
    [ Font.family
        [ Font.typeface "SF Pro Display"
        , Font.sansSerif
        ]
    ]


labelFontStyle : List (Attribute msg)
labelFontStyle =
    [ Font.family
        [ Font.typeface "SF Pro Text"
        , Font.sansSerif
        ]
    ]



-- COLORS


withAlpha : Color -> Float -> Color
withAlpha color alpha =
    let
        { red, green, blue } =
            toRgb color
    in
    rgba red green blue alpha


purpleColor : Color
purpleColor =
    Element.rgb255 89 79 238


tealColor : Color
tealColor =
    Element.rgb255 102 218 213


darkGreenColor : Color
darkGreenColor =
    Element.rgb255 97 165 145


darkTextColor : Color
darkTextColor =
    Element.rgb255 4 31 38


errorColor : Color
errorColor =
    Element.rgb255 200 0 0


fillColor : Color -> Attribute msg
fillColor color =
    Html.Attributes.attribute "fill" (toHex color)
        |> htmlAttribute


fillColorPurple : Attribute msg
fillColorPurple =
    Html.Attributes.style "filter" "brightness(0) saturate(100%) invert(24%) sepia(97%) saturate(1937%) hue-rotate(235deg) brightness(97%) contrast(93%)"
        |> htmlAttribute


fillColorWhite : Attribute msg
fillColorWhite =
    Html.Attributes.style "filter" "brightness(100%) saturate(0) invert(1)"
        |> htmlAttribute


fillColorDarkGreen : Attribute msg
fillColorDarkGreen =
    Html.Attributes.style "filter" "invert(59%) sepia(40%) saturate(342%) hue-rotate(114deg) brightness(93%) contrast(88%)"
        |> htmlAttribute


toHex : Color -> String
toHex color =
    let
        floatToHex float =
            let
                string =
                    Hex.toString (round (float * 255))
            in
            if String.length string == 1 then
                "0" ++ string

            else
                string

        { red, green, blue, alpha } =
            toRgb color

        alphaHex =
            floatToHex alpha

        redHex =
            floatToHex red

        greenHex =
            floatToHex green

        blueHex =
            floatToHex blue
    in
    alphaHex ++ redHex ++ greenHex ++ blueHex



-- CUSTOMIZATIONS


blurredStyle : Attribute msg
blurredStyle =
    classAttr "blurred"


clipStyle : Attribute msg
clipStyle =
    classAttr "safari-clip"


stickyStyle : Attribute msg
stickyStyle =
    classAttr "sticky"


mobileHidden : Attribute msg
mobileHidden =
    classAttr "mobileHidden"


animatesShadow : Attribute msg
animatesShadow =
    classAttr "animatesShadow"


animatesAll : Attribute msg
animatesAll =
    classAttr "animatesAll"


cssResponsive : Attribute msg
cssResponsive =
    classAttr "cssResponsive"


animatesAll20Seconds : Attribute msg
animatesAll20Seconds =
    classAttr "animatesAll20Seconds"


animatesAllDelayed : Attribute msg
animatesAllDelayed =
    classAttr "animatesAllDelayed"



-- HELPERS


classAttr : String -> Attribute msg
classAttr class =
    Html.Attributes.class class
        |> htmlAttribute



-- idAttr : String -> Attribute msg
-- idAttr id =
--     Html.Attributes.id id
--         |> htmlAttribute


edges : { top : Int, right : Int, bottom : Int, left : Int }
edges =
    { top = 0
    , right = 0
    , bottom = 0
    , left = 0
    }
