module Template.TabBar exposing (maxHeight, view)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import Icons
import Navigation exposing (Route)
import Style exposing (edges)


maxHeight : Int
maxHeight =
    50



-- Section


tabSections : List (TabItem msg)
tabSections =
    [ TabItem "Fleet" Icons.vehicle Buses
    , TabItem "Students" Icons.seat HouseholdList
    , TabItem "Routes" Icons.pin Routes
    , TabItem "Crew" Icons.people CrewMembers
    ]


type NavigationPage
    = Buses
    | HouseholdList
    | CrewMembers
    | Routes



-- _ ->
--     Dashboard


type alias TabItem msg =
    { title : String
    , icon : Icons.IconBuilder msg
    , navPage : NavigationPage
    }


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
            { url = Navigation.href (toRoute item.navPage)
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


toRoute : NavigationPage -> Route
toRoute navPage =
    case navPage of
        Buses ->
            Navigation.Buses

        HouseholdList ->
            Navigation.HouseholdList

        CrewMembers ->
            Navigation.CrewMembers

        Routes ->
            Navigation.Routes


toNavigationPage : Route -> NavigationPage
toNavigationPage route =
    case route of
        Navigation.Buses ->
            Buses

        Navigation.Bus _ _ ->
            Buses

        Navigation.BusRegistration ->
            Buses

        Navigation.BusDeviceRegistration _ ->
            Buses

        Navigation.CreateBusRepair _ ->
            Buses

        Navigation.EditBusDetails _ ->
            Buses

        Navigation.CreateFuelReport _ ->
            Buses

        Navigation.HouseholdList ->
            HouseholdList

        Navigation.StudentRegistration ->
            HouseholdList

        Navigation.EditHousehold _ ->
            HouseholdList

        Navigation.Home ->
            Buses

        Navigation.Activate _ ->
            Buses

        Navigation.Login _ ->
            Buses

        Navigation.Logout ->
            Buses

        Navigation.Signup ->
            Buses

        -- Navigation.DeviceRegistration ->
        --     Buses
        -- Navigation.DeviceList ->
        --     Buses
        Navigation.Routes ->
            Routes

        Navigation.CreateRoute ->
            Routes

        Navigation.CrewMembers ->
            CrewMembers

        Navigation.CrewMemberRegistration ->
            CrewMembers

        Navigation.EditCrewMember _ ->
            CrewMembers
