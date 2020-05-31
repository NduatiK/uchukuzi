module Template.TabBar exposing (TabBarItem(..), maxHeight, view)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Region as Region
import Html.Attributes
import Icons
import Navigation exposing (Route)
import Style exposing (edges)
import Template.SideBar exposing (handleBarSpacing, handleBarWidth)


maxHeight : Int
maxHeight =
    50


type TabBarItem msgA
    = Button
        { title : String
        , icon : Icons.IconBuilder msgA
        , onPress : msgA
        }
    | ErrorButton
        { title : String
        , icon : Icons.IconBuilder msgA
        , onPress : msgA
        }
    | LoadingButton
        { title : String
        }


view : List (TabBarItem msgA) -> (msgA -> msg) -> Element msg
view tabBarItems toMsg =
    Element.map toMsg
        (row
            [ spacing 10
            , width fill
            , height (px maxHeight)
            , Background.color Colors.white
            , Border.widthEach { edges | top = 2 }
            , Border.color (Colors.withAlpha Colors.black 0.2)
            ]
            (List.map viewTabItem tabBarItems)
        )


viewTabItem : TabBarItem msg -> Element msg
viewTabItem item =
    el
        ([ paddingXY 56 4
         , width shrink
         , Border.rounded 5
         , Border.width 2
         , centerY
         , centerX
         , Style.overline
         , Border.color Colors.transparent
         , Font.color (Colors.withAlpha (rgb255 4 30 37) 0.69)
         ]
            ++ (case item of
                    Button button ->
                        [ Events.onMouseUp button.onPress
                        , mouseDown [ Background.color Colors.simpleGrey, Border.color (Colors.withAlpha (rgb255 4 30 37) 0.69) ]
                        , mouseOver [ Border.color (Colors.withAlpha (rgb255 4 30 37) 0.39) ]
                        ]

                    ErrorButton button ->
                        [ Events.onMouseUp button.onPress
                        , Border.color Colors.errorRed
                        , Font.color Colors.errorRed
                        , mouseDown [ Border.color Colors.errorRed ]
                        , mouseOver [ Background.color Colors.errorRed, Border.color Colors.errorRed, Font.color Colors.white ]
                        , Colors.fillWhiteOnHover
                        ]

                    LoadingButton _ ->
                        []
               )
        )
        (row
            (centerY
                :: centerX
                :: spacing 4
                :: Font.size 13
                :: Style.defaultFontFace
                ++ [ Font.semiBold
                   ]
            )
            (case item of
                Button button ->
                    [ button.icon [ alignTop, Colors.fillDarkness, alpha 0.69 ]
                    , text button.title
                    ]

                ErrorButton button ->
                    [ button.icon [ alignTop, alpha 1, Colors.fillErrorRed ]
                    , text button.title
                    ]

                LoadingButton loading ->
                    [ Icons.loading [ width (px 24), height (px 24) ]
                    , text loading.title
                    ]
            )
        )
