module Template.SideBar exposing (Model, Msg, handleBarSpacing, handleBarWidth, init, subscriptions, update, view)

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


type NavigationPage
    = Buses
    | HouseholdList
    | CrewMembers
    | Routes
    | Settings


type SideBarOption msg
    = SideBarOption (Section msg)


topPadding =
    100


maxSideBarWidth =
    180


minSideBarWidth =
    54 + handleBarSpacing + (handleBarWidth // 2)


handleBarWidth =
    10


handleBarSpacing =
    8


type alias Section msg =
    { title : String
    , icon : Icons.IconBuilder msg
    , navPage : NavigationPage
    }


sideBarSections : List (SideBarOption msg)
sideBarSections =
    -- [ TopLevel (Section "Fleet" Icons.vehicle Buses)
    -- , TopLevel (Section "Students" Icons.seat HouseholdList)
    -- , TopLevel (Section "Routes" Icons.pin Routes)
    -- , TopLevel (Section "Crew" Icons.people CrewMembers)
    -- ]
    [ SideBarOption (Section "Fleet" Icons.vehicle Buses)
    , SideBarOption (Section "Students" Icons.seat HouseholdList)
    , SideBarOption (Section "Routes" Icons.pin Routes)
    , SideBarOption (Section "Crew" Icons.people CrewMembers)
    ]


type alias Model =
    { isResizing : Bool
    , width : Int
    }


init =
    { isResizing = False
    , width = maxSideBarWidth
    }


type Msg
    = ToggleOpen
    | StartResize
    | StopResize
    | MovedSidebar Int


update msg model =
    case msg of
        ToggleOpen ->
            ( model, Cmd.none )

        StartResize ->
            ( { model | isResizing = True }, Cmd.none )

        StopResize ->
            let
                newWidth =
                    minSideBarWidth + round (percentCollapsed model.width) * (maxSideBarWidth - minSideBarWidth)
            in
            ( { model
                | isResizing = False
                , width = newWidth
              }
            , Cmd.none
            )

        MovedSidebar x ->
            let
                ceiling =
                    maxSideBarWidth
                        + ((x - maxSideBarWidth)
                            |> clamp 0 100
                            |> toFloat
                            |> sqrt
                            |> round
                          )
            in
            if model.isResizing then
                ( { model | width = Basics.clamp minSideBarWidth ceiling x }, Cmd.none )

            else
                ( model, Cmd.none )


view : Maybe Route -> Model -> Int -> Element Msg
view currentRoute state viewHeight =
    row [ width shrink, height fill, spacing 8, htmlAttribute (style "z-index" "10") ]
        [ viewSideBar currentRoute state (toFloat viewHeight)
        , viewResizeHandle
        ]


viewSideBar currentRoute state viewHeight =
    let
        selectedIndex =
            sideBarSections
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, SideBarOption v ) -> Just v.navPage == Maybe.andThen (toNavigationPage >> Just) currentRoute)
                |> List.head
                |> Maybe.andThen (Tuple.first >> Just)
                |> Maybe.withDefault -1

        sideBarWidth =
            state.width - handleBarSpacing - (handleBarWidth // 2)
    in
    column
        [ Background.color Colors.backgroundGray
        , Border.widthEach { edges | right = 1 }
        , Border.color (rgba 0 0 0 0.1)
        , spacing 4
        , alignTop
        , paddingEach { edges | top = topPadding }
        , Region.navigation
        , height fill
        , width (px sideBarWidth)
        , if state.isResizing then
            moveDown 0

          else
            Style.animatesAll
        , behindContent
            (highlightView viewHeight selectedIndex)
        ]
        (List.map (viewSideBarSection state.width currentRoute) sideBarSections
            ++ [ el
                    [ alignBottom
                    , width fill
                    , paddingXY 0 10
                    ]
                    (viewSideBarSection state.width currentRoute (SideBarOption (Section "Settings" Icons.settings Settings)))
               ]
        )


highlightView viewHeight selectedIndex =
    el
        ([ paddingEach
            { edges
                | left = 8
                , top =
                    topPadding
                , right = 8
            }
         , alignLeft
         , width fill
         , Style.animatesAll
         ]
            ++ (if selectedIndex >= 0 then
                    [ moveDown (toFloat (38 * selectedIndex)) ]

                else
                    [ moveDown (viewHeight - 44 - topPadding) ]
               )
        )
        (el
            [ alignLeft
            , width fill
            , height (px 34)
            , Border.rounded 5
            , Background.color highlightColor
            ]
            none
        )


viewSideBarSection width_ currentRoute (SideBarOption item) =
    let
        shouldHighlight =
            case currentRoute of
                Nothing ->
                    True

                Just aRoute ->
                    item.navPage /= toNavigationPage aRoute
    in
    el [ width fill, paddingXY 8 0, alignRight ]
        (link
            [ paddingEach { edges | left = 8, top = 4, bottom = 4, right = 24 }
            , alignLeft
            , width fill
            , Border.rounded 5
            , clip
            , Border.width 1
            , Border.color Colors.transparent
            , Element.mouseOver
                (if shouldHighlight then
                    [ Border.color (Colors.withAlpha Colors.black 0.2)
                    ]

                 else
                    []
                )
            ]
            { url = Navigation.href (toRoute item.navPage)
            , label =
                row (paddingXY 0 2 :: spacing 8 :: Font.size 18 :: sideBarSubSectionStyle)
                    [ el [ width (px 20), height (px 20) ]
                        (item.icon
                            [ centerY
                            , width (px 20)
                            , height (px 20)
                            ]
                        )
                    , el
                        [ alpha (percentCollapsed width_ * percentCollapsed width_ * percentCollapsed width_)
                        ]
                        (text item.title)
                    ]
            }
        )


viewResizeHandle : Element Msg
viewResizeHandle =
    el
        [ Background.color (rgba 0 0 0 0.1)
        , Border.rounded 3
        , width (px handleBarWidth)
        , height (px 40)
        , Style.class "handle"
        , mouseOver
            [ Background.color (rgba 0 0 0 0.2)
            ]
        , Events.onMouseDown StartResize
        ]
        none



-- STYLE


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

        Settings ->
            Navigation.Settings


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

        Navigation.Settings ->
            Settings

        Navigation.Signup ->
            Buses

        Navigation.Routes ->
            Routes

        Navigation.EditRoute _ ->
            Routes

        Navigation.CreateRoute ->
            Routes

        Navigation.CrewMembers ->
            CrewMembers

        Navigation.CrewMemberRegistration ->
            CrewMembers

        Navigation.EditCrewMember _ ->
            CrewMembers


subscriptions model =
    Sub.batch
        (if model.isResizing then
            [ Browser.Events.onMouseMove <|
                Json.map MovedSidebar
                    (Json.field "pageX" Json.int)
            , Browser.Events.onMouseUp <| Json.succeed StopResize
            ]

         else
            []
        )


percentCollapsed width =
    toFloat (width - minSideBarWidth) / toFloat (maxSideBarWidth - minSideBarWidth)
