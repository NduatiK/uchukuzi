module Pages.Buses.Bus.CreateFuelReport exposing (Model, Msg, init, update, view)

import Api
import Api.Endpoint as Endpoint
import Browser.Dom
import Colors
import Date
import DatePicker
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Errors
import Html
import Html.Attributes exposing (id)
import Icons
import Icons.Repairs
import Json.Decode as Decode exposing (Decoder, int, list, string)
import Json.Encode as Encode
import Navigation
import Pages.Buses.Bus.Navigation exposing (BusPage(..))
import RemoteData exposing (..)
import Session exposing (Session)
import Style
import StyledElement
import StyledElement.DatePicker


type alias Model =
    { session : Session
    , bus : Int
    , form : Form
    , requestState : WebData ()
    , datePicker :
        { state : DatePicker.DatePicker
        , hasFailedInput : Bool
        }
    , problems : List (Errors.Errors Problem)
    }


type alias Form =
    { date : Maybe Date.Date
    , cost : Int
    , volume : Float
    , volumeEndsWithDecimal : Bool
    }


type alias ValidForm =
    { date : Date.Date
    , cost : Int
    , volume : Float
    }


init : Int -> Session -> ( Model, Cmd Msg )
init bus session =
    let
        ( datePicker, datePickerCmd ) =
            DatePicker.init
    in
    ( { session = session
      , bus = bus
      , form =
            { date = Nothing
            , cost = 0
            , volume = 0
            , volumeEndsWithDecimal = False
            }
      , requestState = NotAsked
      , datePicker = { state = datePicker, hasFailedInput = False }
      , problems = []
      }
    , Cmd.map DatePickerUpdated datePickerCmd
    )



-- UPDATE


type Msg
    = Submit
    | ReceivedCreateResponse (WebData ())
    | DatePickerUpdated DatePicker.Msg
    | ChangedCost String
    | ChangedVolume String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form
    in
    case msg of
        ChangedCost cost_ ->
            let
                updatedForm =
                    case String.toInt cost_ of
                        Just costInt ->
                            if costInt >= 0 then
                                { form | cost = costInt }

                            else
                                form

                        Nothing ->
                            if cost_ == "" then
                                { form | cost = 0 }

                            else
                                form
            in
            ( { model | form = updatedForm }, Cmd.none )

        ChangedVolume volume_ ->
            let
                updatedForm =
                    case String.toFloat volume_ of
                        Just volume ->
                            if volume >= 0 then
                                { form
                                    | volume = volume
                                    , volumeEndsWithDecimal = String.endsWith "." volume_
                                }

                            else
                                form

                        Nothing ->
                            if volume_ == "" then
                                { form | cost = 0 }

                            else
                                form
            in
            ( { model | form = updatedForm }, Cmd.none )

        DatePickerUpdated datePickerMsg ->
            let
                oldState =
                    model.datePicker

                ( newDatePickerState, event ) =
                    StyledElement.DatePicker.update datePickerMsg model.datePicker.state

                _ =
                    Debug.log "event" event

                hasFailedInput =
                    case event of
                        DatePicker.FailedInput (DatePicker.Invalid _) ->
                            True

                        DatePicker.Picked _ ->
                            False

                        _ ->
                            oldState.hasFailedInput

                date =
                    case event of
                        DatePicker.Picked newDate ->
                            Just newDate

                        _ ->
                            model.form.date
            in
            ( { model
                | datePicker =
                    { oldState
                        | state = newDatePickerState
                        , hasFailedInput = hasFailedInput
                    }
                , form = { form | date = date }
              }
            , Cmd.none
            )

        -- ({model|
        Submit ->
            case validateForm model.form of
                Ok validForm ->
                    ( { model
                        | problems = []
                        , requestState = Loading
                      }
                    , submit model.session model.bus validForm
                    )

                Err problems ->
                    ( { model | problems = Errors.toValidationErrors problems }, Cmd.none )

        ReceivedCreateResponse response ->
            let
                newModel =
                    { model | requestState = response }
            in
            case response of
                Success () ->
                    ( newModel, Navigation.rerouteTo newModel (Navigation.Bus model.bus FuelHistory) )

                Failure error ->
                    let
                        apiFormError =
                            Errors.toServerSideErrors error
                    in
                    ( { newModel | problems = model.problems ++ apiFormError }, Errors.toMsg error )

                _ ->
                    ( { newModel | problems = [] }, Cmd.none )



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    column
        [ paddingXY 80 40
        , width fill
        , height (px viewHeight)
        , spacing 40
        ]
        [ el Style.headerStyle (text "Create Fuel Record")
        , column [ spacing 16 ]
            [ viewDatePicker model
            , viewCostInput model
            , viewVolumeInput model
            , viewButton model.requestState
            ]
        ]


viewButton : WebData a -> Element Msg
viewButton requestState =
    let
        buttonView =
            case requestState of
                Failure _ ->
                    StyledElement.failureButton [ alignRight ]
                        { title = "Try Again"
                        , onPress = Just Submit
                        }

                Loading ->
                    Icons.loading [ alignRight, width (px 46), height (px 46) ]

                _ ->
                    StyledElement.button [ alignRight ]
                        { onPress = Just Submit
                        , label = text "Submit"
                        }
    in
    el (Style.labelStyle ++ [ width fill ])
        buttonView


viewDatePicker : Model -> Element Msg
viewDatePicker model =
    el
        [ width (fill |> minimum 300 |> maximum 300)
        ]
        (StyledElement.DatePicker.view []
            { title = "Purchase Date"
            , caption = Nothing
            , errorCaption = Errors.captionFor model.problems "date" [ EmptyDate ]
            , icon = Nothing
            , onChange = DatePickerUpdated
            , value = model.form.date
            , state = model.datePicker.state
            , hasFailedInput = model.datePicker.hasFailedInput
            }
        )


viewCostInput : Model -> Element Msg
viewCostInput model =
    StyledElement.textInput [ width (fill |> minimum 300 |> maximum 300) ]
        { ariaLabel = "Cost of purchase"
        , caption = Just ""
        , errorCaption = Errors.captionFor model.problems "cost" [ EmptyCost ]
        , icon = Nothing
        , onChange = ChangedCost
        , placeholder = Nothing
        , title = "Fuel Cost"
        , value =
            if model.form.cost == 0 then
                ""

            else
                String.fromInt model.form.cost
        }


viewVolumeInput : Model -> Element Msg
viewVolumeInput model =
    StyledElement.textInput [ width (fill |> minimum 300 |> maximum 300) ]
        { ariaLabel = ""
        , caption = Just "In litres"
        , errorCaption = Errors.captionFor model.problems "volume" [ EmptyVolume ]
        , icon = Nothing
        , onChange = ChangedVolume
        , placeholder = Nothing
        , title = "Volume of fuel"
        , value =
            if model.form.volume == 0 then
                ""

            else if model.form.volumeEndsWithDecimal then
                String.fromFloat model.form.volume ++ "."

            else
                String.fromFloat model.form.volume
        }



-- HTTP


type Problem
    = EmptyCost
    | EmptyDate
    | EmptyVolume


validateForm : Form -> Result (List ( Problem, String )) ValidForm
validateForm record =
    let
        problems =
            List.concat
                [ if record.cost == 0 then
                    [ ( EmptyCost, "Please provide a value" ) ]

                  else
                    []
                , if record.volume == 0 then
                    [ ( EmptyVolume, "Please provide a value" ) ]

                  else
                    []
                , if record.date == Nothing then
                    [ ( EmptyDate, "Please provide a purchase date" ) ]

                  else
                    []
                ]
    in
    case ( problems, record.date ) of
        ( [], Just date ) ->
            Ok
                { date = date
                , volume = record.volume
                , cost = record.cost
                }

        _ ->
            Err problems


submit : Session -> Int -> ValidForm -> Cmd Msg
submit session busID record =
    let
        params =
            Encode.object
                [ ( "date", Encode.string (Date.toIsoString record.date) )
                , ( "cost", Encode.int record.cost )
                , ( "volume", Encode.float record.volume )
                ]
    in
    Api.post session (Endpoint.fuelReports busID) params decoder
        |> Cmd.map ReceivedCreateResponse


decoder : Decoder ()
decoder =
    Decode.succeed ()
