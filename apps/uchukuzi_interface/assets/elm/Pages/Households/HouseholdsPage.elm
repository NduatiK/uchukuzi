module Pages.Households.HouseholdsPage exposing (Model, Msg, init, tabBarItems, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Errors
import Html exposing (Html)
import Html.Attributes exposing (id)
import Html.Events exposing (..)
import Icons
import Json.Decode exposing (list)
import Layout.TabBar as TabBar exposing (TabBarItem(..))
import Models.Household exposing (Household, Student, TravelTime(..), householdDecoder, studentByRouteDecoder)
import Navigation
import Ports
import RemoteData exposing (RemoteData(..), WebData)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import StyledElement.OverlayView as OverlayView
import StyledElement.WebDataView as WebDataView



-- MODEL


type alias GroupedStudents =
    ( String, List Student )


type alias Model =
    { session : Session
    , groupedStudents : WebData ( List GroupedStudents, List Household )
    , selectedGroupedStudents : Maybe GroupedStudents
    , searchText : String
    , selectedStudent :
        Maybe
            { student : Student
            , household : Household
            }
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , groupedStudents = Loading
      , selectedGroupedStudents = Nothing
      , selectedStudent = Nothing
      , searchText = ""
      }
    , fetchHouseholds session
    )



-- UPDATE


type Msg
    = UpdatedSearchText String
    | SelectedStudent (Maybe Student)
    | GenerateCard Student
    | ReceivedStudentsResponse (WebData ( List GroupedStudents, List Household ))
    | RegisterStudent
    | SelectedRoute GroupedStudents
    | EditHousehold Household
    | NoOp



-- | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdatedSearchText text ->
            ( { model | searchText = text }, Cmd.none )

        RegisterStudent ->
            ( model, Navigation.rerouteTo model Navigation.CreateHousehold )

        ReceivedStudentsResponse response ->
            case response of
                Failure error ->
                    ( { model | groupedStudents = response }, Errors.toMsg error )

                Success ( groupedStudents, _ ) ->
                    ( { model
                        | groupedStudents = response
                        , selectedGroupedStudents = List.head groupedStudents
                      }
                    , Cmd.none
                    )

                _ ->
                    ( { model | groupedStudents = response }, Cmd.none )

        SelectedRoute students ->
            ( { model | selectedGroupedStudents = Just students }, Cmd.none )

        SelectedStudent student ->
            case ( model.groupedStudents, student ) of
                ( _, Nothing ) ->
                    ( { model | selectedStudent = Nothing }, Cmd.none )

                ( Success groupedStudents, Just aStudent ) ->
                    let
                        matchingHousehold =
                            List.head
                                (List.filter
                                    (\household ->
                                        List.any (\s -> s.id == aStudent.id) household.students
                                    )
                                    (Tuple.second groupedStudents)
                                )

                        selectedStudent =
                            matchingHousehold
                                |> Maybe.map
                                    (\household ->
                                        { student = aStudent
                                        , household = household
                                        }
                                    )
                    in
                    ( { model | selectedStudent = selectedStudent }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GenerateCard student ->
            ( model, Ports.printCardForStudent student.name )

        EditHousehold household ->
            ( model, Navigation.rerouteTo model (Navigation.EditHousehold household.id) )

        NoOp ->
            ( model, Cmd.none )



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    column
        [ width fill
        , height (px viewHeight)
        , spacing 40
        , padding 30
        , inFront (viewOverlay model viewHeight)
        ]
        [ viewHeading model.searchText
        , viewBody model
        ]


viewOverlay : Model -> Int -> Element Msg
viewOverlay { selectedStudent, session } viewHeight =
    case selectedStudent of
        Nothing ->
            none

        Just { student, household } ->
            let
                travelTime =
                    case student.travelTime of
                        Evening ->
                            "Evening Only"

                        Morning ->
                            "Morning Only"

                        _ ->
                            "Morning and Evening"
            in
            OverlayView.view
                { shouldShowOverlay = selectedStudent /= Nothing
                , hideOverlayMsg = SelectedStudent Nothing
                , height = px viewHeight
                }
                (\_ ->
                    el [ Style.id "student-card", centerX, centerY ]
                        (el
                            [ Background.color Colors.white
                            , Border.rounded 5
                            , Style.elevated2
                            , Style.id "card"
                            , width (fill |> maximum 600)
                            , Style.animatesNone
                            , below
                                (row [ padding 20, centerX, spacing 20 ]
                                    [ StyledElement.hoverButton []
                                        { title = "Print Card"
                                        , icon = Just Icons.print
                                        , onPress = Just (GenerateCard student)
                                        }
                                    , StyledElement.hoverButton [ alignRight ]
                                        { title = "Edit details"
                                        , icon = Just Icons.edit
                                        , onPress = Just (EditHousehold household)
                                        }
                                    ]
                                )
                            ]
                            (column [ spacing 8, paddingXY 0 0, width (px 600), height (px 310) ]
                                [ column [ paddingXY 28 20, spacing 8 ]
                                    [ el [ height (px 12) ] none
                                    , el (Style.header2Style ++ [ padding 0 ]) (text student.name)
                                    ]
                                , row [ spacing 12, paddingXY 28 0, height fill ]
                                    [ el [ Background.color Colors.darkGreen, height fill, width (px 2) ] none
                                    , column [ paddingXY 0 4, spacing 12 ]
                                        [ row []
                                            [ el (Style.header2Style ++ [ padding 0, Font.size 16 ]) (text "Route: ")
                                            , el (Style.labelStyle ++ [ padding 0 ]) (text student.route.name)
                                            ]
                                        , row []
                                            [ el (Style.header2Style ++ [ padding 0, Font.size 16 ]) (text "Guardian Contact: ")
                                            , el Style.labelStyle (text household.guardian.phoneNumber)
                                            ]
                                        ]
                                    ]
                                , row [ width fill, paddingXY 20 20, alignBottom ]
                                    [ image [ width (px 100), height (px 100), alignBottom, alignLeft ]
                                        { src =
                                            "/api/school/households/"
                                                ++ String.fromInt student.id
                                                ++ "/qr_code.svg?token="
                                                ++ (session
                                                        |> Session.getCredentials
                                                        |> Maybe.map .token
                                                        |> Maybe.withDefault ""
                                                   )
                                        , description = ""
                                        }
                                    , el
                                        (Style.labelStyle
                                            ++ [ Font.color Colors.sassyGreyDark
                                               , padding 0
                                               , alignRight
                                               , alignBottom
                                               ]
                                        )
                                        (text travelTime)
                                    ]
                                ]
                            )
                        )
                )


viewHeading : String -> Element Msg
viewHeading searchText =
    row [ spacing 16, width fill ]
        [ Style.iconHeader Icons.seat "Students"
        , el [ width fill ] none
        , StyledElement.textInput [ width fill ]
            { ariaLabel = "Search"
            , caption = Nothing
            , errorCaption = Nothing
            , icon = Just Icons.search
            , onChange = UpdatedSearchText
            , placeholder = Nothing
            , title = ""
            , value = searchText
            }
        ]


viewBody : Model -> Element Msg
viewBody { groupedStudents, selectedGroupedStudents, session, searchText } =
    WebDataView.view groupedStudents
        (\groups ->
            case groups of
                ( [], [] ) ->
                    column (centerX :: spacing 8 :: centerY :: Style.labelStyle)
                        [ el [ centerX ] (text "You have not added any students.")
                        , el [ centerX ] (text "Click the + button below to create one.")
                        ]

                _ ->
                    column [ spacing 40 ]
                        [ viewRoutes groups selectedGroupedStudents
                        , case selectedGroupedStudents of
                            Just students ->
                                let
                                    visibleStudents =
                                        students
                                            |> Tuple.second
                                            |> (if String.isEmpty searchText then
                                                    identity

                                                else
                                                    List.filter
                                                        (\s ->
                                                            s.name
                                                                |> String.toLower
                                                                |> String.contains (String.toLower searchText)
                                                        )
                                               )
                                in
                                if visibleStudents == [] then
                                    el (centerX :: Style.labelStyle) (text ("No students matching \"" ++ searchText ++ "\"."))

                                else
                                    visibleStudents
                                        |> viewHouseholdsTable
                                        |> List.singleton
                                        |> column [ spacing 40, width fill, height fill ]

                            Nothing ->
                                none
                        ]
        )


viewRoutes groups selectedGroupedStudents =
    let
        viewRouteCell group =
            el
                ([ paddingXY 56 4
                 , width shrink
                 , Border.rounded 5
                 , Border.width 1
                 , pointer
                 , centerY
                 , centerX
                 , Font.letterSpacing 0.5
                 , Border.color Colors.simpleGrey
                 , Font.color (Colors.withAlpha (rgb255 4 30 37) 0.69)
                 , Events.onMouseUp (SelectedRoute group)
                 , mouseDown [ Background.color Colors.simpleGrey ]
                 , mouseOver [ Border.color Colors.simpleGrey ]
                 ]
                    ++ (if Just group == selectedGroupedStudents then
                            [ Background.color Colors.simpleGrey ]

                        else
                            []
                       )
                    ++ [ paddingXY 20 4
                       , Border.rounded 5
                       , Font.size 16
                       , Font.medium
                       , centerY
                       , centerX
                       , spacing 4
                       , Font.size 13
                       , Font.semiBold
                       ]
                )
                (text (Tuple.first group))
    in
    wrappedRow [ spacing 8 ] (List.map viewRouteCell (Tuple.first groups))


viewHouseholdsTable : List Student -> Element Msg
viewHouseholdsTable students =
    let
        includesMorningTrip time =
            time == Morning || time == TwoWay

        includesEveningTrip time =
            time == Evening || time == TwoWay

        tableHeader headerText =
            el Style.tableHeaderStyle (text (String.toUpper headerText))

        rowTextStyle =
            width (fill |> minimum 220) :: Style.tableElementStyle
    in
    table
        [ spacing 15 ]
        { data = students
        , columns =
            [ { header = tableHeader "NAME"
              , width = fill
              , view =
                    \student ->
                        StyledElement.plainButton rowTextStyle
                            { label = text student.name
                            , onPress = Just (SelectedStudent (Just student))
                            }
              }
            , { header = tableHeader "MORNING"
              , width = fill
              , view =
                    \student ->
                        Input.checkbox []
                            { onChange = always NoOp
                            , icon = StyledElement.checkboxIcon
                            , checked = includesMorningTrip student.travelTime

                            -- , checked = True
                            , label =
                                Input.labelHidden "Takes morning bus"
                            }
              }
            , { header = tableHeader "EVENING"
              , width = fill
              , view =
                    \student ->
                        Input.checkbox []
                            { onChange = always NoOp
                            , icon = StyledElement.checkboxIcon
                            , checked = includesEveningTrip student.travelTime
                            , label =
                                Input.labelHidden "Takes evening bus"
                            }
              }
            ]
        }



-- HTTP


fetchHouseholds : Session -> Cmd Msg
fetchHouseholds session =
    Api.get session Endpoint.households studentByRouteDecoder
        |> Cmd.map ReceivedStudentsResponse


tabBarItems =
    [ TabBar.Button
        { title = "Add Household"
        , icon = Icons.add
        , onPress = RegisterStudent
        }
    ]
