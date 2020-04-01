module Template.SideBar exposing (viewSidebar)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Element.Region as Region
import Icons
import Route exposing (Route)
import Style exposing (edges)


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


type SidebarOption msg
    = TopLevel (Section msg)
    | Nested String (List (Section msg))


type alias Section msg =
    { title : String
    , icon : Icons.IconBuilder msg
    , navPage : NavigationPage
    }


sidebarSections : List (SidebarOption msg)
sidebarSections =
    -- [ TopLevel (Section "Dashboard" Icons.dashboard Dashboard)
    -- , Nested "Vehicles"
    --     [ Section "Vehicles List" Icons.shuttle Buses
    --     , Section "Fuel List" Icons.fuel Buses
    --     ]
    -- , Nested "Students"
    --     [ Section "Students List" Icons.seat HouseholdList ]
    -- , TopLevel (Section "Devices" Icons.shuttle DeviceList)
    -- ]
    [ TopLevel (Section "Dashboard" Icons.dashboard Dashboard)
    , TopLevel (Section "Fleet" Icons.shuttle Buses)
    , TopLevel (Section "Students" Icons.seat HouseholdList)

    -- , TopLevel (Section "Devices" Icons.shuttle, DeviceList)
    ]


viewSidebar : Maybe Route -> Element msg
viewSidebar currentRoute =
    let
        viewSidebarSection wrappedItem =
            case wrappedItem of
                TopLevel item ->
                    viewTopLevelLink item (colorFor item.navPage currentRoute)

                Nested title subItems ->
                    viewNestedLink title subItems currentRoute
    in
    column
        [ spacing 8
        , alignTop
        , paddingEach { edges | top = 100 }
        , Region.navigation

        -- , Background.color (rgb 1 1 1)
        ]
        (List.map viewSidebarSection sidebarSections)


viewTopLevelLink : Section msg -> Color -> Element msg
viewTopLevelLink item backgroundColor =
    link
        [ paddingEach { edges | left = 24, top = 4, bottom = 4, right = 16 }
        , width fill
        , Background.color backgroundColor
        , Element.mouseOver
            [ Background.color hoverColor
            ]
        ]
        { url = Route.href (toRoute item.navPage)
        , label =
            row (paddingXY 0 4 :: spacing 12 :: Font.size 18 :: sideBarSubSectionStyle)
                [ el [ height (px 32), width (px 32) ] (item.icon [ centerX, centerY ])
                , text item.title
                ]
        }


viewNestedLink title subItems currentPage =
    let
        subSection subItem =
            link
                [ paddingEach { edges | left = 36, right = 16, top = 4, bottom = 4 }
                , width fill
                , Background.color (colorFor subItem.navPage currentPage)
                , Element.mouseOver
                    [ Background.color hoverColor
                    ]
                ]
                { url = Route.href (toRoute subItem.navPage)
                , label =
                    row (paddingXY 0 4 :: spacing 15 :: sideBarSubSectionStyle)
                        [ el [ height (px 24), width (px 24) ] (subItem.icon [ centerX, centerY ])
                        , text subItem.title
                        ]
                }
    in
    column [ width fill, spacing 16 ]
        [ el
            (paddingEach { edges | left = 36 }
                :: sideBarHeadingStyle
                ++ [ Font.regular, Font.size 18 ]
            )
            (text title)
        , column
            (Style.captionLabelStyle
                ++ [ alpha 1
                   , width fill
                   ]
            )
            (List.map subSection subItems)
        ]



-- STYLE


sideBarHeadingStyle : List (Attribute msg)
sideBarHeadingStyle =
    Style.labelStyle
        ++ [ Font.size 14
           , Font.color (rgb255 0 0 0)
           , Font.bold
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
