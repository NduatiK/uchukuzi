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
import Html.Events exposing (..)
import Icons
import Json.Decode exposing (list)
import Models.Household exposing (Household, Student, TravelTime(..), householdDecoder, studentByRouteDecoder)
import Navigation
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
    , selectedStudent : Maybe Student
    }


type Msg
    = SelectedHousehold
    | SelectedStudent (Maybe Student)
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
            ( { model | selectedStudent = student }, Cmd.none )

        SelectedHousehold ->
            ( model, Cmd.none )

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
viewOverlay { selectedStudent } =
    el
        (Style.animatesAll
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

            Just student ->
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
                        (el [ Background.color Colors.white, Border.rounded 5, Style.elevated2, centerX, centerY, width (fill |> maximum 600), Style.animatesNone ]
                            (column [ spacing 8, paddingXY 0 24, width fill ]
                                [ row [ width fill, paddingXY 8 0 ]
                                    [ column [ paddingXY 20 0, spacing 8 ]
                                        [ el (Style.header2Style ++ [ padding 0 ]) (text student.name)

                                        -- , el Style.captionLabelStyle (text (roleToString crewMember.role))
                                        ]
                                    , StyledElement.button [ Background.color Colors.white, alignRight, centerY, mouseOver [ Background.color (Colors.withAlpha Colors.purple 0.2) ] ]
                                        { label =
                                            row [ spacing 8 ]
                                                [ Icons.edit [ Colors.fillPurple ]
                                                , el [ centerY, Font.color Colors.purple ] (text "Edit details")
                                                ]
                                        , onPress = Nothing

                                        -- , onPress = Just (EditCrewMember crewMember)
                                        }
                                    ]
                                , el [ width fill, height (px 2), Background.color Colors.darkness ] none
                                , column [ paddingXY 20 20, spacing 16 ]
                                    [--     el Style.labelStyle (text crewMember.phoneNumber)
                                     -- , el Style.labelStyle (text crewMember.email)
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
