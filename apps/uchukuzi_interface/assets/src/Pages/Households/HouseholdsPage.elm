module Pages.Households.HouseholdsPage exposing (Model, Msg, init, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
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
import Views.Heading exposing (viewHeading)



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


type Msg
    = SelectedHousehold
    | SelectedStudent (Maybe Student)
    | GenerateCard
    | StudentsResponse (WebData ( List GroupedStudents, List Household ))
    | RegisterStudent
    | SelectedRoute GroupedStudents
    | NoOp



-- | NoOp


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


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    -- let
    --     form =
    --         model.form
    -- in
    case msg of
        RegisterStudent ->
            ( model, Navigation.rerouteTo model Navigation.StudentRegistration )

        StudentsResponse response ->
            case response of
                Failure error ->
                    let
                        ( _, error_msg ) =
                            Errors.decodeErrors error
                    in
                    ( { model | groupedStudents = response }, error_msg )

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
                            Maybe.andThen
                                (\household ->
                                    Just
                                        { student = aStudent
                                        , household = household
                                        }
                                )
                                matchingHousehold
                    in
                    ( { model | selectedStudent = selectedStudent }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SelectedHousehold ->
            ( model, Cmd.none )

        GenerateCard ->
            ( model, Ports.printCard )

        NoOp ->
            ( model, Cmd.none )



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    column
        [ width fill
        , height (px viewHeight)
        , spacing 40
        , paddingXY 90 70
        , inFront (viewOverlay model)
        ]
        [ viewHeading model
        , viewBody model
        ]


viewOverlay : Model -> Element Msg
viewOverlay { selectedStudent, session } =
    el
        (htmlAttribute (id "cards")
            :: Style.animatesAll
            :: (if selectedStudent == Nothing then
                    [ alpha 0 ]

                else
                    [ alpha 1
                    , width fill
                    , height fill
                    ]
               )
        )
        (case selectedStudent of
            Nothing ->
                none

            Just { student, household } ->
                el
                    [ width fill
                    , height fill
                    , behindContent
                        (Input.button
                            [ width fill
                            , height fill
                            , Background.color (Colors.withAlpha Colors.black 0.6)
                            , Style.blurredStyle
                            ]
                            { onPress = Just (SelectedStudent Nothing)
                            , label = none
                            }
                        )
                    , inFront
                        (el
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
                                        { title = "Generate Card"
                                        , icon = Just Icons.card
                                        , onPress = Just GenerateCard
                                        }
                                    , StyledElement.hoverButton [ alignRight ]
                                        { title = "Edit details"
                                        , icon = Just Icons.edit
                                        , onPress = Nothing
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
                                            , el (Style.labelStyle ++ [ padding 0 ]) (text student.route)
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
                                                ++ Maybe.withDefault "" (Maybe.andThen (.token >> Just) (Session.getCredentials session))
                                        , description = ""
                                        }
                                    , column [ paddingXY 0 4, spacing 12, alignRight ]
                                        [ if student.travelTime == Evening then
                                            none

                                          else
                                            el (Style.labelStyle ++ [ Font.color Colors.sassyGreyDark, padding 0, alignRight ]) (text "Morning")
                                        , if student.travelTime == Morning then
                                            none

                                          else
                                            el (Style.labelStyle ++ [ Font.color Colors.sassyGreyDark, padding 0, alignRight ]) (text "Evening")
                                        ]
                                    ]
                                ]
                            )
                        )
                    ]
                    none
        )


viewHeading : Model -> Element Msg
viewHeading model =
    row [ spacing 16, width fill ]
        [ el Style.headerStyle (text "Students")
        , StyledElement.ghostButton [ alignRight ]
            { title = "Add Household"
            , icon = Icons.add
            , onPress = Just RegisterStudent
            }
        ]


viewBody { groupedStudents, selectedGroupedStudents } =
    case groupedStudents of
        NotAsked ->
            text "Initialising."

        Loading ->
            el [ width fill, height fill ] (Icons.loading [ centerX, centerY ])

        Failure error ->
            let
                ( apiError, _ ) =
                    Errors.decodeErrors error
            in
            text (Errors.errorToString apiError)

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
        title group =
            StyledElement.plainButton []
                { label =
                    el
                        ((if Just group == selectedGroupedStudents then
                            [ Background.color Colors.darkGreen, Font.color Colors.white, Border.width 1, Border.color (Colors.withAlpha Colors.black 0.1) ]

                          else
                            [ Background.color Colors.white, Border.width 2, Border.color Colors.sassyGrey ]
                         )
                            ++ [ paddingXY 12 6
                               , Border.rounded 5
                               ]
                        )
                        (text (Tuple.first group))
                , onPress = Just (SelectedRoute group)
                }
    in
    wrappedRow [] (List.map title (Tuple.first groups))


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

            -- , { header = tableHeader "ROUTE"
            --   , width = fill
            --   , view =
            --         \household ->
            --             el rowTextStyle (Element.text household.route)
            --   }
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

                            -- , checked = includesEveningTrip student.time
                            , checked = True
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
        |> Cmd.map StudentsResponse
