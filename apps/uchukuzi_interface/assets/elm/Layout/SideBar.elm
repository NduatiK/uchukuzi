port module Layout.SideBar exposing
    ( Model
    , Msg
    , handleBarSpacing
    , handleBarWidth
    , init
    , subscriptions
    , unwrapWidth
    , update
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
import Icons
import Json.Decode as Json
import Navigation exposing (Route)
import Style exposing (edges)


port setOpenState : Bool -> Cmd msg


type NavigationPage
    = Buses
    | HouseholdList
    | CrewMembers
    | Routes
    | Settings


type SideBarOption msg
    = SideBarOption (Section msg)


topPadding : Int
topPadding =
    100


maxSideBarWidth : Int
maxSideBarWidth =
    180


minSideBarWidth : Int
minSideBarWidth =
    54 + handleBarSpacing + (handleBarWidth // 2)


handleBarWidth : Int
handleBarWidth =
    10


handleBarSpacing : Int
handleBarSpacing =
    8


type alias Section msg =
    { title : String
    , icon : Icons.IconBuilder msg
    , navPage : NavigationPage
    }


sideBarSections : List (SideBarOption msg)
sideBarSections =
    [ SideBarOption (Section "Fleet" Icons.vehicle Buses)
    , SideBarOption (Section "Students" Icons.seat HouseholdList)
    , SideBarOption (Section "Routes" Icons.pin Routes)
    , SideBarOption (Section "Crew" Icons.people CrewMembers)
    ]


type alias Model =
    { isResizing : Bool
    , hasDraggedHandle : Bool
    , width : Int
    }


init : Bool -> Model
init isOpen =
    { isResizing = False
    , hasDraggedHandle = False
    , width =
        if isOpen then
            maxSideBarWidth

        else
            minSideBarWidth
    }


type Msg
    = StartResize
    | StopResize
    | MovedSidebar Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        StartResize ->
            ( { model | isResizing = True, hasDraggedHandle = False }, Cmd.none )

        StopResize ->
            if model.hasDraggedHandle then
                let
                    newWidth =
                        minSideBarWidth + round (percentCollapsed model.width) * (maxSideBarWidth - minSideBarWidth)

                    isOpen =
                        newWidth == maxSideBarWidth
                in
                ( { model
                    | isResizing = False
                    , hasDraggedHandle = False
                    , width = newWidth
                  }
                , setOpenState isOpen
                )

            else
                let
                    toggledWidth =
                        minSideBarWidth + round (1 - percentCollapsed model.width) * (maxSideBarWidth - minSideBarWidth)

                    isOpen =
                        toggledWidth == maxSideBarWidth
                in
                ( { model
                    | isResizing = False
                    , width = toggledWidth
                  }
                , setOpenState isOpen
                )

        MovedSidebar x ->
            let
                ceiling =
                    maxSideBarWidth
                        + ((x - maxSideBarWidth)
                            |> clamp 0 10000
                            |> toFloat
                            |> sqrt
                            |> round
                          )

                finalWidth =
                    Basics.clamp minSideBarWidth ceiling x
            in
            if model.isResizing then
                ( { model | width = finalWidth, hasDraggedHandle = True }, Cmd.none )

            else
                ( model, Cmd.none )


view : Maybe Route -> Model -> Int -> Element Msg
view currentRoute state viewHeight =
    row [ width shrink, height fill, spacing 8, htmlAttribute (style "z-index" "10") ]
        [ viewSideBarList currentRoute state (toFloat viewHeight)
        , viewResizeHandle
        ]


viewSideBarList : Maybe Route -> Model -> Float -> Element Msg
viewSideBarList currentRoute state viewHeight =
    let
        selectedIndex =
            sideBarSections
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, SideBarOption v ) -> Just v.navPage == (currentRoute |> Maybe.map toNavigationPage))
                |> List.head
                |> Maybe.map Tuple.first
                |> Maybe.withDefault -1

        sideBarWidth =
            state.width - handleBarSpacing - (handleBarWidth // 2)
    in
    column
        [ Background.color Colors.backgroundGray
        , Border.widthEach { edges | right = 2 }
        , Border.color (rgb 0.8 0.8 0.8)
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


highlightView : Float -> Int -> Element Msg
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
                    [ moveDown (viewHeight - 44 - toFloat topPadding) ]
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


viewSideBarSection : Int -> Maybe Route -> SideBarOption Msg -> Element Msg
viewSideBarSection viewWidth currentRoute (SideBarOption item) =
    let
        shouldHighlight =
            case currentRoute of
                Nothing ->
                    True

                Just aRoute ->
                    item.navPage /= toNavigationPage aRoute
    in
    el [ width fill, paddingXY 8 0, alignRight, height (px 34) ]
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
                        [ alpha (toFloat viewWidth ^ 3)
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

        Navigation.CreateBusPage ->
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

        Navigation.CreateHousehold ->
            HouseholdList

        Navigation.EditHousehold _ ->
            HouseholdList

        Navigation.Home ->
            Buses

        Navigation.Activate _ ->
            Buses

        Navigation.Login _ ->
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

        Navigation.CreateCrewMember ->
            CrewMembers

        Navigation.EditCrewMember _ ->
            CrewMembers


subscriptions : Model -> Sub Msg
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


percentCollapsed : Int -> Float
percentCollapsed width =
    toFloat (width - minSideBarWidth) / toFloat (maxSideBarWidth - minSideBarWidth)


unwrapWidth : Model -> Int
unwrapWidth { width } =
    width
