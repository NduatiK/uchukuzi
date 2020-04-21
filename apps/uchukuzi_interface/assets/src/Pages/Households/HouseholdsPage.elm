module Pages.Households.HouseholdsPage exposing (Model, Msg, init, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Input as Input
import Errors
import Html exposing (Html)
import Html.Events exposing (..)
import Icons
import Json.Decode exposing (list)
import Models.Household exposing (Household, Student, householdDecoder)
import Navigation
import RemoteData exposing (RemoteData(..), WebData)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import Views.Heading exposing (viewHeading)



-- MODEL


type alias Model =
    { session : Session
    , households : WebData (List Household)
    }


type TripTime
    = TwoWay
    | Morning
    | Evening


type Msg
    = SelectedHousehold
    | SelectedStudent Student
    | StudentsResponse (WebData (List Household))
    | RegisterStudent
    | NoOp



-- | NoOp


init : Session -> ( Model, Cmd Msg )
init session =
    ( Model session Loading
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
                    ( { model | households = response }, error_msg )

                _ ->
                    ( { model | households = response }, Cmd.none )

        _ ->
            ( model, Cmd.none )



-- VIEW


view : Model -> Element Msg
view model =
    Element.column
        [ width fill, spacing 40, paddingXY 24 8 ]
        [ viewHeading model
        , viewBody model.households
        ]


viewHeading : Model -> Element Msg
viewHeading model =
    row [ spacing 16 ]
        [ Element.column
            [ width fill ]
            [ el
                Style.headerStyle
                (text "All Households")

            -- , case subLine of
            --     Nothing ->
            --         none
            --     Just caption ->
            --         el Style.captionLabelStyle (text caption)
            ]
        , StyledElement.iconButton []
            { icon = Icons.add
            , iconAttrs = [ Colors.fillWhite ]
            , onPress = Just RegisterStudent
            }
        ]


viewBody model =
    case model of
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

        Success households ->
            Element.column [ spacing 40 ]
                [ viewHouseholdsTable households
                ]


viewHouseholdsTable : List Household -> Element Msg
viewHouseholdsTable households =
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
        { data = households
        , columns =
            [ { header = tableHeader "NAME"
              , width = fill
              , view =
                    \household ->
                        el rowTextStyle (Element.text household.guardian.name)
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

                            -- , checked = includesMorningTrip student.time
                            , checked = True
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
    Api.get session Endpoint.households (list householdDecoder)
        |> Cmd.map StudentsResponse
