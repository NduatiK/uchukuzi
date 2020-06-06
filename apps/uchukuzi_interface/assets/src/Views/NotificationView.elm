module Views.NotificationView exposing
    ( Notification
    , icon
    , view
    )

import Browser.Events
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Region as Region
import Html.Attributes exposing (style)
import Html.Events exposing (on)
import Icons
import Json.Decode as Json
import Navigation exposing (Route)
import Style exposing (edges)
import StyledElement
import Time


type alias Notification =
    { time : Time.Posix
    , notificationType : String
    , content : String
    }


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


view : List String -> Element msg
view notifications =
    el ([ alignTop, alignRight, padding 30, Style.clickThrough ] ++ Style.labelStyle)
        (el
            [ Style.nonClickThrough
            , Background.color Colors.backgroundPurple
            , Border.color Colors.semiDarkText
            , Border.width 1
            , Border.rounded 5
            , padding 13
            , Style.elevated2
            , width (px 300)
            ]
            -- none
            (row [ spacing 10 ]
                [ Icons.info [ Colors.fillDarkness, alpha 1 ]
                , text "KAU361 has left the school"
                ]
            )
        )
