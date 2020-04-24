module Template.Sidebar exposing (view)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Element.Region as Region
import Icons
import Navigation exposing (Route)
import Style exposing (edges)
import StyledElement


type NavigationPage
    = Buses
    | HouseholdList
    | CrewMembers
    | Routes


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
    [ TopLevel (Section "Fleet" Icons.vehicle Buses)
    , TopLevel (Section "Students" Icons.seat HouseholdList)
    , TopLevel (Section "Routes" Icons.pin Routes)
    , TopLevel (Section "Crew" Icons.people CrewMembers)
    ]


view : Maybe Route -> Bool -> msg -> Element msg
view currentRoute open sidebarToggleMsg =
    column
        [ spacing 8
        , alignTop
        , Style.animatesAll
        , paddingEach { edges | top = 100 }
        , Region.navigation
        , height fill
        , if open then
            width shrink

          else
            width (px 54)

        -- , Background.color (rgb 1 1 1)
        ]
        (List.map (viewSidebarSection open currentRoute) sidebarSections
            ++ [ el [ alignBottom, alignLeft, paddingXY 12 12 ]
                    (StyledElement.iconButton [ Background.color Colors.transparent, centerX ]
                        { icon = Icons.chevronDown
                        , iconAttrs =
                            [ if open then
                                rotate (pi / 2)

                              else
                                rotate (-pi / 2)
                            ]
                        , onPress = Just sidebarToggleMsg
                        }
                    )
               ]
        )


viewSidebarSection open currentRoute wrappedItem =
    case wrappedItem of
        TopLevel item ->
            viewTopLevelLink item open (colorFor item.navPage currentRoute)

        Nested title subItems ->
            viewNestedLink title open subItems currentRoute


viewTopLevelLink : Section msg -> Bool -> Color -> Element msg
viewTopLevelLink item open backgroundColor =
    link
        [ paddingEach { edges | left = 16, top = 4, bottom = 4, right = 24 }
        , width fill
        , Background.color backgroundColor
        , Element.mouseOver
            [ Background.color hoverColor
            ]
        ]
        { url = Navigation.href (toRoute item.navPage)
        , label =
            row (paddingXY 0 8 :: spacing 8 :: Font.size 18 :: sideBarSubSectionStyle)
                [ el [ height (px 24), width (px 24) ] (item.icon [ centerX, centerY ])
                , el
                    [ if open then
                        alpha 1

                      else
                        alpha 0
                    ]
                    (text item.title)

                -- (text (String.toUpper item.title))
                -- , el [ Font.semiBold, Font.variantList [ Font.smallCaps ] ] (text (String.toUpper item.title))
                ]
        }


viewNestedLink title open subItems currentPage =
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
                { url = Navigation.href (toRoute subItem.navPage)
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
            (Style.captionStyle
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

        Navigation.CreateFuelReport _ ->
            Buses

        Navigation.HouseholdList ->
            HouseholdList

        Navigation.StudentRegistration ->
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
