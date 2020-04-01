module Template.TabBar exposing (maxHeight, view)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import Icons
import Route exposing (Route)
import Style exposing (edges)


maxHeight : Int
maxHeight =
    50


type NavigationPage
    = Dashboard
    | Buses
    | HouseholdList
    | DeviceList


toRoute : NavigationPage -> Route
toRoute navPage =
    case navPage of
        Dashboard ->
            Route.Dashboard

        Buses ->
            Route.Buses

        HouseholdList ->
            Route.HouseholdList

        DeviceList ->
            Route.DeviceList


toNavigationPage : Route -> NavigationPage
toNavigationPage route =
    case route of
        Route.Dashboard ->
            Dashboard

        Route.Buses ->
            Buses

        Route.Bus _ ->
            Buses

        Route.BusRegistration ->
            Buses

        Route.BusDeviceRegistration _ ->
            Buses

        Route.HouseholdList ->
            HouseholdList

        Route.StudentRegistration ->
            HouseholdList

        Route.DeviceList ->
            DeviceList

        Route.Home ->
            Dashboard

        Route.Login _ ->
            Dashboard

        Route.Logout ->
            Dashboard

        Route.Signup ->
            Dashboard

        Route.DeviceRegistration ->
            DeviceList



-- _ ->
--     Dashboard


type alias TabItem msg =
    { title : String
    , icon : Icons.IconBuilder msg
    , navPage : NavigationPage
    }



-- Section


tabSections : List (TabItem msg)
tabSections =
    [ TabItem "Dashboard" Icons.dashboard Dashboard
    , TabItem "Fleet" Icons.shuttle Buses
    , TabItem "Students" Icons.seat HouseholdList
    , TabItem "Routes" Icons.pin HouseholdList
    ]


view : Maybe Route -> Element msg
view currentRoute =
    let
        viewSidebarSection item =
            viewTabItem item (colorFor item.navPage currentRoute)
    in
    row
        [ spacing 10
        , width fill
        , height (px maxHeight)
        , Border.shadow { offset = ( 0, 0 ), size = 1, blur = 0, color = rgba 0 0 0 0.24 }
        ]
        [ el [] none
        , row
            [ spaceEvenly
            , width fill
            , alignTop
            , Region.navigation

            -- , Background.color (rgb 1 1 1)
            ]
            (List.map viewSidebarSection tabSections)
        , el [] none
        ]


viewTabItem : TabItem msg -> Color -> Element msg
viewTabItem item backgroundColor =
    column
        [ width fill
        ]
        [ el [ Background.color backgroundColor, width fill, height (px 3) ] none
        , link
            [ paddingEach { edges | left = 24, top = 4, bottom = 4, right = 16 }
            , width fill

            -- , Background.color (rgba 0 0 0 0)
            , below
                (el
                    [ Background.color hoverColor
                    , width fill
                    , height fill
                    ]
                    none
                )
            ]
            { url = Route.href (toRoute item.navPage)
            , label =
                row (paddingXY 0 4 :: centerX :: spacing 12 :: Font.size 18 :: sideBarSubSectionStyle)
                    [ el [ height (px 32), width (px 32) ] (item.icon [ centerX, centerY ])
                    , text item.title
                    ]
            }
        ]


sideBarSubSectionStyle : List (Attribute msg)
sideBarSubSectionStyle =
    Style.labelStyle
        ++ [ Font.size 17

           --    , Font.color (rgb255 0 0 0)
           ]


colorFor : NavigationPage -> Maybe Route -> Color
colorFor navPage1 route =
    case route of
        Nothing ->
            rgba 0 0 0 0

        Just aRoute ->
            if navPage1 == toNavigationPage aRoute then
                highlightColor

            else
                rgba 0 0 0 0


highlightColor : Color
highlightColor =
    Colors.teal


hoverColor : Color
hoverColor =
    let
        color =
            toRgb highlightColor
    in
    fromRgb { color | alpha = 0.9 }
