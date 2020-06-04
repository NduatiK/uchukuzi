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
import Models.Household exposing (Household, Student, TravelTime(..), householdDecoder, studentByRouteDecoder)
import Navigation
import Ports
import RemoteData exposing (RemoteData(..), WebData)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import Template.TabBar as TabBar exposing (TabBarItem(..))



-- MODEL


type alias GroupedStudents =
    ( String, List Student )


type alias Model =
    { session : Session
    , groupedStudents : WebData ( List GroupedStudents, List Household )
    , selectedGroupedStudents : Maybe GroupedStudents
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
      }
    , fetchHouseholds session
    )



-- UPDATE


type Msg
    = SelectedHousehold
    | SelectedStudent (Maybe Student)
    | GenerateCard
    | ReceivedStudentsResponse (WebData ( List GroupedStudents, List Household ))
    | RegisterStudent
    | SelectedRoute GroupedStudents
    | EditHousehold Household
    | NoOp



-- | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RegisterStudent ->
            ( model, Navigation.rerouteTo model Navigation.StudentRegistration )

        ReceivedStudentsResponse response ->
            case response of
                Failure error ->
                    let
                        ( _, error_msg ) =
                            Errors.decodeErrors error
                    in
                    ( { model | groupedStudents = response }, error_msg )

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

        SelectedHousehold ->
            ( model, Cmd.none )

        GenerateCard ->
            ( model, Ports.printCard )

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
        , inFront (viewOverlay model)
        ]
        [ viewHeading
        , viewBody model
        ]


viewOverlay : Model -> Element Msg
viewOverlay { selectedStudent, session } =
    el
        (htmlAttribute (id "cards")
            :: Style.animatesAll
            :: width fill
            :: height fill
            :: behindContent
                (Input.button
                    [ width fill
                    , height fill
                    , Background.color (Colors.withAlpha Colors.black 0.6)
                    , Style.blurredStyle
                    , if selectedStudent == Nothing then
                        Style.clickThrough

                      else
                        Style.nonClickThrough
                    ]
                    { onPress = Just (SelectedStudent Nothing)
                    , label = none
                    }
                )
            :: (if selectedStudent == Nothing then
                    [ alpha 0, Style.clickThrough ]

                else
                    [ alpha 1
                    ]
               )
        )
        (case selectedStudent of
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
                el
                    [ Background.color Colors.white
                    , Border.rounded 5
                    , Style.elevated2
                    , centerX
                    , centerY
                    , width (fill |> maximum 600)
                    , Style.animatesNone
                    , below
                        (row [ padding 20, centerX, spacing 20 ]
                            [ StyledElement.hoverButton []
                                { title = "Print Card"
                                , icon = Just Icons.print
                                , onPress = Just GenerateCard
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
                        , row [ spacing 12, paddingXY 28 0 ]
                            [ el [ Background.color Colors.darkGreen, height fill, width (px 2) ] none
                            , column [ paddingXY 0 4, spacing 12 ]
                                [ row []
                                    [ el (Style.header2Style ++ [ padding 0, Font.size 16 ]) (text "Route: ")
                                    , el (Style.labelStyle ++ [ padding 0 ]) (text student.route.name)
                                    ]
                                , row []
                                    [ el (Style.header2Style ++ [ padding 0, Font.size 16 ]) (text "Guardian: ")
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


viewHeading : Element Msg
viewHeading =
    row [ spacing 16, width fill ]
        [ Style.iconHeader Icons.seat "Students"

        -- , StyledElement.ghostButton [ alignRight ]
        --     { title = "Add Household"
        --     , icon = Icons.add
        --     , onPress = Just RegisterStudent
        --     }
        ]


viewBody : Model -> Element Msg
viewBody { groupedStudents, selectedGroupedStudents } =
    case groupedStudents of
        NotAsked ->
            text "Initialising."

        Loading ->
            row [ width fill, height fill ] [ el [ width fill, height fill ] (Icons.loading [ centerX, centerY ]) ]

        Failure error ->
            let
                ( apiError, _ ) =
                    Errors.decodeErrors error
            in
            text (Errors.errorToString apiError)

        Success ( [], [] ) ->
            column (centerX :: spacing 8 :: centerY :: Style.labelStyle)
                [ el [ centerX ] (text "You have not added any students.")
                , el [ centerX ] (text "Click the + button above to create one do so.")
                ]

        Success groups ->
            Element.column [ spacing 40 ]
                [ viewRoutes groups selectedGroupedStudents
                , case selectedGroupedStudents of
                    Just students ->
                        Element.column [ spacing 40 ]
                            [ viewHouseholdsTable students
                            ]

                    Nothing ->
                        none
                ]


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


viewHouseholdsTable : GroupedStudents -> Element Msg
viewHouseholdsTable students =
    let
        includesMorningTrip time =
            time == Morning || time == TwoWay

        includesEveningTrip time =
            time == Evening || time == TwoWay

        tableHeader text =
            el Style.tableHeaderStyle (Element.text (String.toUpper text))

        rowTextStyle =
            width (fill |> minimum 220) :: Style.tableElementStyle
    in
    Element.table
        [ spacing 15 ]
        { data = Tuple.second students
        , columns =
            [ { header = tableHeader "NAME"
              , width = fill
              , view =
                    \student ->
                        StyledElement.plainButton rowTextStyle
                            { label = Element.text student.name
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
