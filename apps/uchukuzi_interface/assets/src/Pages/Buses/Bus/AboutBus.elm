module Pages.Buses.Bus.AboutBus exposing (Model, Msg, init, locationUpdateMsg, tabBarItems, update, view, viewFooter)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Icons
import Json.Decode exposing (list)
import Layout.TabBar as TabBar exposing (TabBarItem(..))
import Models.Bus exposing (Bus, LocationUpdate)
import Models.CrewMember exposing (CrewMember, crewDecoder)
import Models.Household exposing (Student, studentDecoder)
import Models.Route exposing (Route)
import Navigation
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement exposing (textStack, textStackWithSpacing)
import StyledElement.Footer as Footer


type alias Model =
    { bus : Bus
    , route : WebData (Maybe Route)
    , crew : WebData (List CrewMember)
    , studentsOnboard : WebData (List Student)
    , session : Session
    , currentPage : Page
    }


type Page
    = Statistics
    | Students (Maybe Student)
    | Crew


pageToString : Page -> String
pageToString page =
    case page of
        Statistics ->
            "Statistics"

        Students _ ->
            "Students Onboard"

        Crew ->
            "Crew"


type Msg
    = ClickedStatisticsPage
      --------------------
    | ClickedStudentsPage
    | FetchStudentsOnboard
    | ReceivedStudentsOnboardResponse (WebData (List Student))
    | SelectedStudent Student
      --------------------
    | ClickedCrewPage
    | ReceivedCrewMembersResponse (WebData (List CrewMember))
      --------------------
    | ReceivedRouteResponse (WebData (Maybe Route))
      --------------------
    | LocationUpdate LocationUpdate
    | EditDetails


init : Session -> Bus -> Maybe LocationUpdate -> ( Model, Cmd Msg )
init session bus locationUpdate_ =
    ( { bus = bus
      , crew = NotAsked
      , route = Loading
      , studentsOnboard = Loading
      , session = session
      , currentPage = Statistics
      }
    , Cmd.batch
        [ Ports.initializeMaps
        , Ports.fitBounds
        , fetchStudentsOnboard session bus.id
        , fetchRoute session bus.id
        , case locationUpdate_ of
            Just locationUpdate ->
                Ports.updateBusMap locationUpdate

            Nothing ->
                case bus.lastSeen of
                    Just lastSeen ->
                        Ports.updateBusMap lastSeen

                    Nothing ->
                        Cmd.none
        ]
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedStatisticsPage ->
            ( { model | currentPage = Statistics }
            , Cmd.batch
                [ Ports.initializeMaps
                , case model.route of
                    Success (Just route) ->
                        Ports.drawRoute route

                    _ ->
                        Cmd.none
                ]
            )

        ClickedStudentsPage ->
            ( { model | currentPage = Students Nothing }, Cmd.none )

        SelectedStudent student ->
            ( { model | currentPage = Students (Just student) }
            , Cmd.batch
                [ Ports.initializeMaps
                , Ports.showStaticHomeLocation student.homeLocation
                ]
            )

        ReceivedStudentsOnboardResponse response ->
            ( { model | studentsOnboard = response }, Cmd.none )

        ReceivedRouteResponse response ->
            ( { model | route = response }
            , case response of
                Success (Just route) ->
                    Ports.drawRoute route

                _ ->
                    Cmd.none
            )

        FetchStudentsOnboard ->
            ( model, fetchStudentsOnboard model.session model.bus.id )

        ReceivedCrewMembersResponse response ->
            ( { model | crew = response }, Cmd.none )

        ClickedCrewPage ->
            ( { model | currentPage = Crew }, fetchCrewMembers model.session model.bus.id )

        EditDetails ->
            ( model, Navigation.rerouteTo model (Navigation.EditBusDetails model.bus.id) )

        LocationUpdate locationUpdate ->
            let
                currentBus =
                    model.bus
            in
            ( { model | bus = { currentBus | lastSeen = Just locationUpdate } }
            , Ports.updateBusMap locationUpdate
            )


locationUpdateMsg : LocationUpdate -> Msg
locationUpdateMsg =
    LocationUpdate



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight_ =
    let
        viewHeight =
            viewHeight_ - 180
    in
    case model.currentPage of
        Statistics ->
            viewStatisticsPage model

        Students _ ->
            viewStudentsPage model viewHeight

        Crew ->
            viewCrewPage model


viewGMAP : Element Msg
viewGMAP =
    StyledElement.googleMap [ height fill, width (fillPortion 2) ]


viewStatisticsPage : Model -> Element Msg
viewStatisticsPage model =
    let
        sidebarViews =
            case model.bus.lastSeen of
                Nothing ->
                    el [] none

                Just lastSeen ->
                    --  textStack "Distance Travelled" "2,313 km"
                    -- , textStack "Fuel Consumed" "3,200 l"
                    -- column [ height fill, spaceEvenly, width (px 300) ]
                    column [ height fill, spaceEvenly, width shrink ]
                        [ el [] none
                        , textStack "Current Speed" (String.fromFloat lastSeen.speed ++ " km/h")
                        , textStack "Repairs Made" (String.fromInt (List.length model.bus.repairs))
                        , el [] none
                        ]
    in
    row [ width fill, height fill, spacing 24 ]
        [ viewGMAP
        , sidebarViews
        ]


viewStudentsPage : Model -> Int -> Element Msg
viewStudentsPage model viewHeight =
    let
        viewStudent index student =
            let
                selected =
                    Students (Just student) == model.currentPage

                highlightAttrs =
                    [ Background.color Colors.darkGreen, Font.color Colors.white ]
            in
            Input.button [ width fill, paddingXY 2 0 ]
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
                        [ text (String.fromInt (index + 1) ++ ". " ++ student.name) ]
                , onPress = Just (SelectedStudent student)
                }

        gradient =
            el
                [ paddingEach { edges | right = 12 }, width fill, alignBottom ]
                (el
                    [ height (px 36)
                    , width fill
                    , Colors.withGradient 0 Colors.white
                    ]
                    none
                )
    in
    row [ width fill, height (fill |> maximum viewHeight), spacing 24 ]
        [ viewGMAP
        , case model.studentsOnboard of
            Failure _ ->
                column [ centerX, centerY, spacing 20 ]
                    [ paragraph [] [ text "Unable to load students" ]
                    , StyledElement.failureButton [ centerX ]
                        { title = "Try Again"
                        , onPress = Just FetchStudentsOnboard
                        }
                    ]

            Success students ->
                if students == [] then
                    column [ centerX, centerY, spacing 20 ]
                        [ paragraph [] [ text "0 students currently onboard" ]
                        ]

                else
                    el
                        [ alignTop
                        , width fill
                        , height (shrink |> maximum viewHeight)
                        , Border.color Colors.darkGreen
                        , Border.width 2
                        , if (36 * List.length students) > viewHeight then
                            inFront gradient

                          else
                            moveUp 0
                        , clip
                        ]
                        (column
                            [ width fill
                            , scrollbarY
                            ]
                            (List.indexedMap viewStudent students
                                ++ (if (36 * List.length students) > viewHeight then
                                        [ el [ height (px 36) ] none ]

                                    else
                                        []
                                   )
                            )
                        )

            _ ->
                el [ centerX, centerY ] (Icons.loading [])
        ]


viewCrewPage : Model -> Element Msg
viewCrewPage model =
    let
        viewEmployee role name phone email =
            el [ width fill, height fill ]
                (column [ centerY, centerX, spacing 8, width (fill |> maximum 300) ]
                    [ row [ width fill ] [ textStackWithSpacing role name 8 ]
                    , el [ width fill, height (px 2), Background.color (Colors.withAlpha Colors.darkness 0.34) ] none
                    , el [] none
                    , el Style.labelStyle (text phone)
                    , el Style.labelStyle (text email)
                    ]
                )

        viewCrewMember member =
            viewEmployee (Models.CrewMember.roleToString member.role) member.name member.phoneNumber member.email
    in
    case model.crew of
        Failure _ ->
            StyledElement.failureButton [ centerX ]
                { title = "Try Again"
                , onPress = Just ClickedCrewPage
                }

        Success crew ->
            if crew == [] then
                column [ centerX, centerY, spacing 20 ]
                    [ paragraph [] [ text "No crew driver or assistant assigned" ]
                    , StyledElement.ghostButtonLink [ centerX ]
                        { title = "Assign crew"
                        , route = Navigation.CrewMembers
                        }
                    ]

            else
                row [ spacing 20, centerY, width fill ]
                    (List.map viewCrewMember crew)

        _ ->
            el [ centerX, centerY ] (Icons.loading [])


viewFooter : Model -> Element Msg
viewFooter model =
    Footer.view model.currentPage
        pageToString
        [ ( Statistics, "", ClickedStatisticsPage )
        , case model.studentsOnboard of
            Success students ->
                ( Students Nothing
                , students
                    |> List.length
                    |> String.fromInt
                , ClickedStudentsPage
                )

            _ ->
                ( Students Nothing, "", ClickedStudentsPage )
        , ( Crew, "", ClickedCrewPage )
        ]


tabBarItems : (Msg -> msg) -> List (TabBarItem msg)
tabBarItems mapper =
    [ TabBar.Button
        { title = "Edit details"
        , icon = Icons.edit
        , onPress = EditDetails |> mapper
        }
    ]


fetchCrewMembers : Session -> Int -> Cmd Msg
fetchCrewMembers session busID =
    Api.get session (Endpoint.crewMembersForBus busID) (list crewDecoder)
        |> Cmd.map ReceivedCrewMembersResponse


fetchStudentsOnboard : Session -> Int -> Cmd Msg
fetchStudentsOnboard session busID =
    Api.get session (Endpoint.studentsOnboard busID) (list studentDecoder)
        |> Cmd.map ReceivedStudentsOnboardResponse


fetchRoute session busID =
    Api.get session (Endpoint.routeForBus busID) (Json.Decode.nullable Models.Route.routeDecoder)
        |> Cmd.map ReceivedRouteResponse
