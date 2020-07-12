module Layout.TabBar exposing (TabBarItem(..), maxHeight, view)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Icons
import Navigation exposing (Route)
import Style exposing (edges)


maxHeight : Int
maxHeight =
    60


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
        ([ paddingXY 56 6
         , width shrink
         , Border.rounded 5
         , Border.width 2
         , centerY
         , centerX
         , Style.overline
         , Font.color (Colors.withAlpha (rgb255 4 30 37) 0.69)
         ]
            ++ (case item of
                    Button button ->
                        [ Events.onMouseUp button.onPress
                        , Border.color Colors.sassyGrey
                        , Style.animatesShadowOnly
                        , Background.color Colors.white
                        , mouseDown
                            [ Border.color Colors.purple
                            , Background.color Colors.purple
                            , Font.color Colors.white
                            ]
                        , mouseOver
                            [ Border.color Colors.purple
                            , Font.color Colors.purple
                            , moveUp 1
                            , Border.shadow { offset = ( 2, 4 ), size = 0, blur = 8, color = rgba 0 0 0 0.2 }
                            ]
                        , Colors.fillPurpleOnHover
                        , Colors.fillWhiteOnClick
                        ]

                    ErrorButton button ->
                        [ Events.onMouseUp button.onPress
                        , Border.color Colors.errorRed
                        , Font.color Colors.errorRed
                        , mouseDown
                            [ Background.color Colors.errorRed
                            , Border.color Colors.errorRed
                            , moveUp 1
                            , Border.shadow { offset = ( 2, 4 ), size = 0, blur = 8, color = rgba 0 0 0 0.2 }
                            ]
                        , mouseOver
                            [ Background.color (Colors.withAlpha Colors.errorRed 0.8)
                            , Border.color Colors.errorRed
                            , Font.color Colors.white
                            ]
                        , Colors.fillWhiteOnHover
                        ]

                    LoadingButton ->
                        [ Border.color Colors.darkGreen
                        ]
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
                    [ el [ width (px 24), height (px 24) ] (button.icon [ centerX, centerY, alignTop, Colors.fillDarkness, alpha 0.8 ])
                    , text button.title
                    ]

                ErrorButton button ->
                    [ el [ width (px 24), height (px 24) ] (button.icon [ centerX, centerY, alignTop, alpha 1, Colors.fillErrorRed ])
                    , text button.title
                    ]

                -- LoadingButton title ->
                LoadingButton ->
                    [ Icons.loading [ width (px 24), height (px 24) ]

                    -- , text title
                    ]
            )
        )
