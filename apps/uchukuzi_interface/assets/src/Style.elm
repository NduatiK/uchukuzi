module Style exposing
    ( animatesAll
    , animatesAll20Seconds
    , animatesAllDelayed
    , animatesNone
    , animatesShadow
    , blurredStyle
    , borderedContainer
    , captionStyle
    , class
    , clickThrough
    , clipStyle
    , cssResponsive
    , defaultFontFace
    , edges
    , elevated
    , elevated2
    , elevatedTile
    , errorStyle
    , header2Style
    , headerStyle
    , iconHeader
    , ignoreCss
    , labelStyle
    , mobileHidden
    , nonClickThrough
    , normalScrolling
    , overline
    , reverseScrolling
    , stickyStyle
    , tableElementStyle
    , tableHeaderStyle
    )

import Colors exposing (..)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import Html.Attributes
import Html.Events
import Json.Decode


elevated : Attr decorative msg
elevated =
    Border.shadow { offset = ( 0, 0 ), size = 0, blur = 5, color = rgba 0 0 0 0.14 }


elevated2 : Attr decorative msg
elevated2 =
    Border.shadow { offset = ( 0, 0 ), size = 0, blur = 10, color = rgba 0 0 0 0.24 }


elevatedTile : Attr decorative msg
elevatedTile =
    Border.shadow { offset = ( 0, 2 ), size = 0, blur = 24, color = Colors.withAlpha Colors.sassyGrey 0.37 }



-- STYLES


iconHeader icon title =
    row [ spacing 8 ]
        [ icon [ alpha 1, height (px 31), width (px 31), Colors.fillDarkness, centerY ]
        , el headerStyle (text title)
        ]


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


captionStyle : List (Attribute msg)
captionStyle =
    [ Font.size 13
    , Font.color (Colors.withAlpha (rgb255 4 30 37) 0.69)
    ]
        ++ defaultFontFace


errorStyle : List (Attribute msg)
errorStyle =
    labelStyle ++ [ Font.color errorRed ]


labelStyle : List (Attribute msg)
labelStyle =
    [ Font.size 16
    , Font.color (rgb255 51 63 78)
    ]
        ++ defaultFontFace


tableHeaderStyle : List (Attribute msg)
tableHeaderStyle =
    [ Region.heading 4
    , Font.size 14
    , Font.color Colors.semiDarkness
    , Font.letterSpacing 0.58
    , Font.bold
    , alignLeft
    ]
        ++ defaultFontFace


tableElementStyle : List (Attribute msg)
tableElementStyle =
    [ Region.heading 4
    , Font.size 18
    , Font.color (rgb255 96 96 96)
    , alignLeft
    ]
        ++ defaultFontFace


{-| Sets Font.family to custom font
-}
defaultFontFace : List (Attribute msg)
defaultFontFace =
    [ Font.family
        [ Font.typeface "SF Pro Text"
        , Font.sansSerif
        ]
    ]



-- CUSTOMIZATIONS


blurredStyle : Attribute msg
blurredStyle =
    class "blurred"


clipStyle : Attribute msg
clipStyle =
    class "safari-clip"


overline : Attribute msg
overline =
    class "overline"


stickyStyle : Attribute msg
stickyStyle =
    class "sticky"


mobileHidden : Attribute msg
mobileHidden =
    class "mobileHidden"


animatesShadow : Attribute msg
animatesShadow =
    class "animatesShadow"


reverseScrolling : Attribute msg
reverseScrolling =
    htmlAttribute (Html.Attributes.style "direction" "rtl")


normalScrolling : Attribute msg
normalScrolling =
    htmlAttribute (Html.Attributes.style "direction" "ltr")


animatesAll : Attribute msg
animatesAll =
    class "animatesAll"


animatesNone : Attribute msg
animatesNone =
    class "animatesNone"


ignoreCss : Attribute msg
ignoreCss =
    class "ignoreCss"


cssResponsive : Attribute msg
cssResponsive =
    class "cssResponsive"


animatesAll20Seconds : Attribute msg
animatesAll20Seconds =
    class "animatesAll20Seconds"


animatesAllDelayed : Attribute msg
animatesAllDelayed =
    class "animatesAllDelayed"



-- HELPERS


class : String -> Attribute msg
class className =
    Html.Attributes.class className
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


clickThrough =
    class "clickThrough"


nonClickThrough =
    class "nonClickThrough"


