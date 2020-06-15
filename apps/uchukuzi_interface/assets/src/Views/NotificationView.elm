module Views.NotificationView exposing
    ( icon
    , view
    )

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Icons
import Models.Notification exposing (Notification)
import Navigation
import Style exposing (edges)
import StyledElement


icon : List Notification -> msg -> Element msg
icon notifications onPress =
    StyledElement.iconButton
        [ Border.rounded 24
        , Background.color Colors.white
        , alpha 1
        ]
        { icon =
            if notifications == [] then
                Icons.notificationsEmpty

            else
                Icons.notificationsFilled
        , iconAttrs =
            [ Border.rounded 24
            , alpha 1
            , Colors.fillDarkness
            , if notifications == [] then
                Style.class ""

              else
                Style.class "shakingBell"
            , inFront
                (if notifications == [] then
                    none

                 else
                    el
                        [ width (px 10)
                        , height (px 10)
                        , alignRight
                        , Border.rounded 5
                        , Border.width 1
                        , Border.color Colors.white
                        , Background.color Colors.darkGreen
                        ]
                        none
                )
            ]
        , onPress = Just onPress
        }


view : List Notification -> (String -> msg) -> Element msg
view notifications redirectTo =
    -- let
    --     notifications =
    --         [ { notificationType = "String"
    --           , content =
    --                 """
    --             Icons.notificationsEmpty [ width (px 100), height (px 100), centerX, alpha 1, Colors.fillDarkness ]
    --             , el [ centerX ] (text "Nothing to see here")
    --             """
    --           , title = "String"
    --           , seen = True
    --           }
    --         ]
    -- in
    if notifications == [] then
        el [ padding 30, width fill, height (px 300) ]
            (column
                [ centerX
                , height fill
                , spacing 16
                ]
                [ el [ height (px 30) ] none
                , Icons.notificationsEmpty
                    [ width (px 100)
                    , height (fill |> minimum 100)
                    , centerX
                    , alpha 1
                    , Colors.fillDarkness
                    , inFront
                        (el
                            [ width (px 10)
                            , height fill
                            , Background.color Colors.darkness
                            , Border.shadow
                                { blur = 0, color = Colors.white, offset = ( 8, 0 ), size = 0 }
                            , Border.color Colors.white
                            , moveUp 33
                            , centerX
                            , centerY
                            , rotate (pi / 4)
                            ]
                            none
                        )
                    ]
                , el [ centerX ] (text "Nothing to see here")
                ]
            )

    else
        column
            [ width fill
            , height (fill |> maximum 300)
            , scrollbarY
            ]
            (List.map (viewMessage redirectTo) notifications)


viewMessage : (String -> msg) -> Notification -> Element msg
viewMessage redirectTo notification =
    let
        canRedirect =
            not (String.isEmpty notification.redirectUrl)
    in
    row
        ([ width fill
         , height (fill |> minimum 70)
         , Border.shadow { offset = ( 0, 0 ), size = 0, blur = 2, color = rgba 0 0 0 0.24 }
         , padding 16
         , if notification.seen then
            Background.color Colors.backgroundGray

           else
            Background.color Colors.white
         ]
            ++ (if canRedirect then
                    [ mouseOver
                        [ Background.color Colors.backgroundPurple
                        , Border.color (Colors.withAlpha Colors.purple 1)
                        ]
                    , Events.onClick (redirectTo notification.redirectUrl)
                    , pointer
                    ]

                else
                    []
               )
        )
        [ el
            [ Border.rounded 8
            , width (px 8)
            , height (px 8)
            , if notification.seen then
                Background.color Colors.sassyGrey

              else
                Background.color Colors.purple
            ]
            none
        , el [ width (px 16) ] none
        , column [ width fill ]
            [ paragraph [ width fill, padding 0 ]
                [ el [ width fill, Font.bold, Font.size 16 ] (text notification.title)
                ]
            , paragraph [ width fill ]
                [ el (width fill :: Style.captionStyle) (text notification.content)
                ]
            ]
        , if canRedirect then
            el
                [ Background.color Colors.backgroundGray
                , width (px 24)
                , height (px 24)
                , Border.rounded 12
                , centerY
                , alignRight
                ]
                (Icons.chevronDown [ rotate (pi / -2), centerX, centerY, moveRight 1 ])

          else
            none
        ]
