module Pages.Buses.AboutBus exposing (Model, Msg, init, locationUpdateMsg, update, view, viewFooter)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Lazy
import Icons
import Json.Decode exposing (list)
import Models.Bus exposing (Bus, LocationUpdate, Route)
import Models.CrewMember exposing (CrewMember, crewDecoder)
import Models.Household exposing (Student, studentDecoder)
import Navigation
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement exposing (textStack, textStackWithSpacing)
import StyledElement.Footer as Footer


type alias Model =
    { bus : Bus
    , crew : WebData (List CrewMember)
    , studentsOnboard : WebData (List Student)
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
    | FetchStudentsOnboard
    | StudentsOnboardServerResponse (WebData (List Student))
    | SelectedStudent Int
      --------------------
    | ClickedRoute
      --------------------
    | ClickedCrewPage
    | CrewMemberServerResponse (WebData (List CrewMember))
      --------------------
    | LocationUpdate LocationUpdate


init : Session -> Bus -> ( Model, Cmd Msg )
init session bus =
    ( { bus = bus
      , crew = NotAsked
      , studentsOnboard = Loading
      , session = session
      , currentPage = Statistics
      }
    , Cmd.batch
        [ Ports.initializeMaps False
        , fetchStudentsOnboard session bus.id
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

        StudentsOnboardServerResponse response ->
            ( { model | studentsOnboard = response }, Cmd.none )

        FetchStudentsOnboard ->
            ( model, fetchStudentsOnboard model.session model.bus.id )

        ClickedRoute ->
            ( { model | currentPage = Route }, Ports.initializeMaps False )

        CrewMemberServerResponse response ->
            ( { model | crew = response }, Cmd.none )

        ClickedCrewPage ->
            ( { model | currentPage = Crew }, fetchCrewMembers model.session model.bus.id )

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

                        -- , textStack "Fuel Consumed" "3,200 l"
                        , textStack "Current Speed" (String.fromFloat last_seen.speed ++ " km/h")
                        , textStack "Repairs Made" (String.fromInt (List.length model.bus.repairs))
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
                        [ text student.name ]
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
        [ -- viewGMAP
          -- ,
          column [ width fill, height fill ]
            [ --      Input.button [ width fill, height fill ]
              --     { label = row [ spacing 10 ] [ el Style.header2Style (text "All Students"), Icons.chevronDown [ rotate (-pi / 2) ] ]
              --     , onPress = Nothing
              --     }
              -- ,
              case model.studentsOnboard of
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
                                    students
                                )
                            )

                _ ->
                    el [ centerX, centerY ] (Icons.loading [])
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
                column [ centerX, spacing 20 ]
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

        -- , ( Route
        --   , case model.bus.route of
        --         Just route ->
        --             route.name
        --         _ ->
        --             "Not set"
        --   , ClickedRoute
        --   )
        , ( Crew, "", ClickedCrewPage )
        ]


fetchCrewMembers session busID =
    Api.get session (Endpoint.crewMembersForBus busID) (list crewDecoder)
        |> Cmd.map CrewMemberServerResponse


fetchStudentsOnboard session busID =
    Api.get session (Endpoint.studentsOnboard busID) (list studentDecoder)
        |> Cmd.map StudentsOnboardServerResponse
