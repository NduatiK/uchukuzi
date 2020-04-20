module Pages.Buses.AboutBus exposing (Model, Msg, init, locationUpdateMsg, update, view, viewFooter)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Lazy
import Icons
import Models.Bus exposing (Bus, LocationUpdate, Route)
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement exposing (textStack, textStackWithSpacing)
import StyledElement.Footer as Footer


type alias Model =
    { showGeofence : Bool
    , bus : Bus
    , session : Session
    , currentPage : Page
    }


type Page
    = Statistics
    | Students (Maybe Int)
    | Route
    | Crew


pageToString : Page -> String
pageToString page =
    case page of
        Statistics ->
            "Statistics"

        Students _ ->
            "Students Onboard"

        Route ->
            "Route"

        Crew ->
            "Crew"


type Msg
    = ClickedStatisticsPage
      --------------------
    | ClickedStudentsPage
    | SelectedStudent Int
      --------------------
    | ClickedRoute
    | ClickedCrewPage
      --------------------
    | LocationUpdate LocationUpdate


init : Session -> Bus -> ( Model, Cmd Msg )
init session bus =
    ( Model True bus session Statistics
    , Cmd.batch
        [ Ports.initializeMaps False
        ]
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedStatisticsPage ->
            ( { model | currentPage = Statistics }, Ports.initializeMaps False )

        ClickedStudentsPage ->
            ( { model | currentPage = Students Nothing }, Cmd.none )

        SelectedStudent index ->
            ( { model | currentPage = Students (Just index) }, Ports.initializeMaps False )

        ClickedRoute ->
            ( { model | currentPage = Route }, Ports.initializeMaps False )

        ClickedCrewPage ->
            ( { model | currentPage = Crew }, Cmd.none )

        LocationUpdate locationUpdate ->
            let
                currentBus =
                    model.bus
            in
            ( { model | bus = { currentBus | last_seen = Just locationUpdate } }, Cmd.none )


locationUpdateMsg : LocationUpdate -> Msg
locationUpdateMsg =
    LocationUpdate



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    case model.currentPage of
        Statistics ->
            viewStatisticsPage model

        Students _ ->
            viewStudentsPage model viewHeight

        Route ->
            viewRoutePage model

        Crew ->
            viewCrewPage model


viewGMAP : Element Msg
viewGMAP =
    Element.Lazy.lazy StyledElement.googleMap [ height (fill |> minimum 300), width (fillPortion 2) ]


viewStatisticsPage : Model -> Element Msg
viewStatisticsPage model =
    let
        sidebarViews =
            List.concat
                [ [ el [] none ]
                , case model.bus.last_seen of
                    Nothing ->
                        []

                    Just last_seen ->
                        [ textStack "Distance Travelled" "2,313 km"
                        , textStack "Fuel Consumed" "3,200 l"
                        , textStack "Current Speed" (String.fromFloat last_seen.speed ++ " km/h")
                        , textStack "Repairs Made" "23"
                        ]
                , [ el [] none ]
                ]
    in
    wrappedRow [ width fill, height fill, spacing 24 ]
        [ viewGMAP
        , column [ height fill, spaceEvenly, width (px 300) ] sidebarViews
        ]


viewStudentsPage : Model -> Int -> Element Msg
viewStudentsPage model viewHeight =
    let
        viewStudent index student =
            let
                selected =
                    Students (Just index) == model.currentPage

                highlightAttrs =
                    [ Background.color Colors.darkGreen, Font.color Colors.white ]
            in
            Input.button [ width fill, paddingEach { edges | right = 12 } ]
                { label =
                    paragraph
                        (Style.header2Style
                            ++ [ paddingXY 4 10, Font.size 16, width fill, mouseOver highlightAttrs, Style.animatesAll ]
                            ++ (if selected then
                                    highlightAttrs

                                else
                                    [ Background.color Colors.white, Font.color Colors.darkGreen ]
                               )
                        )
                        -- [ text (String.fromInt (index + 1) ++ ". " ++ student) ]
                        [ text student ]
                , onPress = Just (SelectedStudent index)
                }

        gradient =
            el
                [ paddingEach { edges | right = 12 }, width fill, alignBottom ]
                (el
                    [ height (px 36)
                    , width fill
                    , Colors.withGradient pi Colors.white
                    ]
                    none
                )
    in
    wrappedRow [ width fill, height fill, spacing 24 ]
        [ viewGMAP
        , column [ width fill, height fill ]
            [ Input.button [ width fill, height fill ]
                { label = row [ spacing 10 ] [ el Style.header2Style (text "All Students"), Icons.chevronDown [ rotate (-pi / 2) ] ]
                , onPress = Nothing
                }
            , el
                [ width fill
                , height (fill |> maximum (viewHeight // 2))
                , Border.color Colors.darkGreen
                , Border.width 0
                , inFront gradient
                ]
                (column
                    [ width fill
                    , height (fill |> maximum (viewHeight // 2))
                    , scrollbarY
                    , paddingEach { edges | bottom = 24 }
                    ]
                    (List.indexedMap viewStudent
                        [ "Bansilal Brata"
                        , "Bansilal Brata"
                        , "  Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        , "Bansilal Brata"
                        ]
                    )
                )
            ]
        ]


viewRoutePage : Model -> Element Msg
viewRoutePage model =
    wrappedRow [ width fill, height fill, spacing 24 ]
        [ viewGMAP ]


viewCrewPage : Model -> Element Msg
viewCrewPage model =
    let
        viewEmployee role name phone email =
            el [ width fill, height fill ]
                (column [ centerY, centerX, spacing 8, width (fill |> maximum 300) ]
                    [ row [ width fill ] [ textStackWithSpacing role name 8, Icons.chevronDown [ rotate (-pi / 2), alignBottom, moveUp 16 ] ]
                    , el [ width fill, height (px 2), Background.color (Colors.withAlpha Colors.darkness 0.34) ] none
                    , el [] none
                    , el Style.labelStyle (text phone)
                    , el Style.labelStyle (text email)
                    ]
                )
    in
    row [ spacing 20, centerY, width fill ]
        [ viewEmployee "Assistant" "Thomas Magnum" "Phone Number" "Email"
        , el [ width (px 2), height (fill |> maximum 300), centerX, Background.color Colors.darkness ] none
        , viewEmployee "Driver" "James Ferrazi" "Phone Number" "Email"
        ]



-- wrappedRow
--     [ height fill
--     , width fill
--     , paddingXY 0 10
--     ]
--     [ if model.bus.device == Nothing then
--         viewAddDevice model
--       else
--         none
--     ]


viewFooter : Model -> Element Msg
viewFooter model =
    Footer.view model.currentPage
        pageToString
        [ ( Statistics, "", ClickedStatisticsPage )
        , ( Students Nothing, "2", ClickedStudentsPage )
        , ( Route
          , case model.bus.route of
                Just route ->
                    route.name

                _ ->
                    "Not set"
          , ClickedRoute
          )
        , ( Crew, "Thomas Magnum + 1", ClickedCrewPage )
        ]
