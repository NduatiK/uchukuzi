module Pages.Buses.CreateBusPage exposing (Model, Msg, init, subscriptions, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Errors
import Html.Events exposing (..)
import Http
import Icons
import Json.Decode exposing (Decoder, field, float, int, string)
import Json.Encode as Encode
import Models.Bus exposing (VehicleType(..))
import Navigation
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement exposing (toDropDownView)
import StyledElement.DropDown as Dropdown
import StyledElement.FloatInput as FloatInput exposing (FloatInput)
import Task
import Utils.Validator as Validator
import Views.Heading exposing (viewHeading)



-- MODEL


type alias Model =
    { session : Session
    , form : Form
    , routeDropdownState : Dropdown.State String
    , fuelDropdownState : Dropdown.State FuelType
    , consumptionDropdownState : Dropdown.State ConsumptionType
    , requestState : WebData Int
    }


type alias Form =
    { vehicleClass : VehicleClass
    , numberPlate : String
    , seatsAvailable : Int
    , routeId : Maybe String
    , consumptionType : ConsumptionType
    , consumptionAmount : FloatInput
    , problems : List (Errors.Errors Problem)
    }


type Problem
    = InvalidNumberPlate


type alias ValidForm =
    { vehicleType : String
    , numberPlate : String
    , seatsAvailable : Int
    , routeId : Maybe String
    , consumptionAmount : Float
    , fuelType : String
    }


type ConsumptionType
    = Custom
    | Default


type FuelType
    = Gasoline
    | Diesel


type VehicleClass
    = VehicleClass VehicleType FuelType


type Field
    = VehicleType VehicleType
    | FuelType FuelType
    | NumberPlate String
    | SeatsAvailable Int
    | Route (Maybe String)
    | FuelConsumptionType ConsumptionType
    | FuelConsumptionAmount FloatInput


emptyForm : Session -> Model
emptyForm session =
    let
        defaultVehicle =
            VehicleClass SchoolBus Diesel
    in
    { session = session
    , form =
        { vehicleClass = defaultVehicle
        , numberPlate = ""
        , seatsAvailable = defaultSeats defaultVehicle
        , routeId = Nothing
        , consumptionType = Default
        , consumptionAmount = FloatInput.fromFloat (defaultConsumption defaultVehicle)
        , problems = []
        }
    , routeDropdownState = Dropdown.init "routeDropdown"
    , fuelDropdownState = Dropdown.init "fuelDropdown"
    , consumptionDropdownState = Dropdown.init "consumptionDropdown"
    , requestState = NotAsked
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( emptyForm session
    , Cmd.batch
        [ Ports.initializeMaps False
        , Task.succeed (FuelDropdownMsg (Dropdown.selectOption Diesel)) |> Task.perform identity
        , Task.succeed (ConsumptionDropdownMsg (Dropdown.selectOption Default)) |> Task.perform identity
        ]
    )



-- UPDATE


type Msg
    = Changed Field
    | SubmitButtonMsg
    | ServerResponse (WebData Int)
    | RouteDropdownMsg (Dropdown.Msg String)
    | FuelDropdownMsg (Dropdown.Msg FuelType)
    | ConsumptionDropdownMsg (Dropdown.Msg ConsumptionType)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Changed field ->
            updateField field model

        RouteDropdownMsg subMsg ->
            let
                ( _, config, options ) =
                    routeDropDown model

                ( state, cmd ) =
                    Dropdown.update config subMsg model.routeDropdownState options
            in
            ( { model | routeDropdownState = state }, cmd )

        FuelDropdownMsg subMsg ->
            let
                ( _, config, options ) =
                    fuelDropDown model

                ( state, cmd ) =
                    Dropdown.update config subMsg model.fuelDropdownState options
            in
            ( { model | fuelDropdownState = state }, cmd )

        ConsumptionDropdownMsg subMsg ->
            let
                ( _, config, options ) =
                    consumptionDropDown model

                ( state, cmd ) =
                    Dropdown.update config subMsg model.consumptionDropdownState options
            in
            ( { model | consumptionDropdownState = state }, cmd )

        SubmitButtonMsg ->
            let
                form =
                    model.form
            in
            case validateForm form of
                Ok validForm ->
                    ( { model
                        | form = { form | problems = [] }
                        , requestState = Loading
                      }
                    , submit model.session validForm
                    )

                Err problems ->
                    ( { model | form = { form | problems = Errors.toClientSideErrors problems } }, Cmd.none )

        ServerResponse response ->
            let
                newModel =
                    { model | requestState = response }

                form =
                    newModel.form
            in
            case response of
                Success bus_id ->
                    ( newModel, Navigation.rerouteTo newModel (Navigation.Bus bus_id Nothing) )

                Failure error ->
                    let
                        ( _, error_msg ) =
                            Errors.decodeErrors error

                        apiFormError =
                            Errors.toServerSideErrors
                                error

                        updatedForm =
                            { form | problems = form.problems ++ apiFormError }
                    in
                    ( { newModel | form = updatedForm }, error_msg )

                _ ->
                    ( { newModel | form = { form | problems = [] } }, Cmd.none )


updateField : Field -> Model -> ( Model, Cmd Msg )
updateField field model =
    let
        form =
            model.form
    in
    case field of
        VehicleType vehicleType ->
            let
                vehicleClass =
                    VehicleClass vehicleType (toFuelType form.vehicleClass)

                updated_form =
                    { form
                        | vehicleClass = vehicleClass
                        , seatsAvailable = defaultSeats vehicleClass
                        , consumptionAmount =
                            if form.consumptionType == Default then
                                FloatInput.fromFloat (defaultConsumption vehicleClass)

                            else
                                form.consumptionAmount
                    }
            in
            ( { model | form = updated_form }, Cmd.none )

        FuelType fuelType ->
            let
                updated_form =
                    { form | vehicleClass = VehicleClass (toVehicleType form.vehicleClass) fuelType }
            in
            ( { model | form = updated_form }, Cmd.none )

        NumberPlate plate ->
            let
                updated_form =
                    { form | numberPlate = plate }
            in
            ( { model | form = updated_form }, Cmd.none )

        SeatsAvailable seats ->
            let
                updated_form =
                    { form | seatsAvailable = seats }
            in
            ( { model | form = updated_form }, Cmd.none )

        Route route ->
            let
                updated_form =
                    { form | routeId = route }
            in
            ( { model | form = updated_form }, Cmd.none )

        FuelConsumptionType consumptionType ->
            let
                updated_form =
                    { form
                        | consumptionType = consumptionType
                        , consumptionAmount =
                            if consumptionType == Default then
                                FloatInput.fromFloat (defaultConsumption form.vehicleClass)

                            else
                                form.consumptionAmount
                    }
            in
            ( { model | form = updated_form }, Cmd.none )

        FuelConsumptionAmount consumptionAmount ->
            let
                updated_form =
                    { form | consumptionAmount = consumptionAmount }
            in
            ( { model | form = updated_form }, Cmd.none )



-- VIEW


view : Model -> Element Msg
view model =
    row [ width fill, height fill ]
        [ viewBody model
        ]


viewBody : Model -> Element Msg
viewBody model =
    Element.column
        [ width fill, spacing 40, paddingXY 24 8, alignTop ]
        [ viewHeading "Add a Vehicle" Nothing
        , viewForm model
        ]


viewForm : Model -> Element Msg
viewForm model =
    let
        form =
            model.form
    in
    column [ spacing 50, paddingEach { edges | bottom = 100 } ]
        [ viewTypePicker form.vehicleClass
        , viewDivider
        , wrappedRow [ spaceEvenly, width fill ]
            [ column
                [ spacing 32, width (fill |> minimum 300 |> maximum 300), alignTop ]
                [ viewNumberPlateInput form.numberPlate form.problems
                , viewAvailableSeatingInput form.seatsAvailable form.problems
                , viewRouteDropDown model
                ]
            , viewVerticalDivider
            , column
                [ spacing 32, width (fill |> minimum 300 |> maximum 300), alignTop ]
                [ viewFuelTypeDropDown model
                , viewConsumptionDropDown model
                , if form.consumptionType == Custom then
                    viewConsumptionInput form.consumptionAmount

                  else
                    none
                ]
            ]
        , viewButton model.requestState
        ]


viewTypePicker : VehicleClass -> Element Msg
viewTypePicker vehicleClass =
    wrappedRow [ spacing 32 ]
        [ viewVehicle SchoolBus vehicleClass
        , viewVehicle Shuttle vehicleClass
        , viewVehicle Van vehicleClass
        ]


viewVehicle : VehicleType -> VehicleClass -> Element Msg
viewVehicle vehicleType currentClass =
    let
        currentType =
            toVehicleType currentClass

        selected =
            currentType == vehicleType

        name =
            case vehicleType of
                Van ->
                    "Van"

                Shuttle ->
                    "Mini Bus / Shuttle"

                SchoolBus ->
                    "Bus"

        icon =
            vehicleTypeToIcon vehicleType

        selectedAttr =
            if selected then
                [ Border.color Colors.purple
                , Border.shadow { offset = ( 0, 12 ), size = 0, blur = 16, color = Colors.withAlpha Colors.darkGreen 0.2 }
                ]

            else
                [ Border.color (rgb 1 1 1) ]
    in
    Input.button []
        { label =
            column
                ([ centerY
                 , Border.width 3
                 , spacing 16
                 , Style.animatesAllDelayed
                 , paddingEach { edges | top = 41, right = 33, left = 33, bottom = 12 }
                 ]
                    ++ selectedAttr
                )
                [ icon []
                , el [ centerX, Font.bold, Font.color Colors.purple, Font.size 21 ] (text name)
                ]
        , onPress = Just (Changed (VehicleType vehicleType))
        }


viewNumberPlateInput : String -> List (Errors.Errors Problem) -> Element Msg
viewNumberPlateInput numberPlate problems =
    let
        errorMapper =
            Errors.inputErrorsFor problems
    in
    StyledElement.textInput
        [ width
            (fill
                |> maximum 300
            )
        , alignTop
        ]
        { ariaLabel = "Number Plate"
        , caption = Nothing
        , errorCaption =
            errorMapper "number_plate" [ InvalidNumberPlate ]
        , icon = Nothing
        , onChange = String.toUpper >> NumberPlate >> Changed
        , placeholder = Just (Input.placeholder [] (text "Eg. KXX123X or KXX123"))
        , title = "Number Plate"
        , value = numberPlate
        }


viewAvailableSeatingInput : Int -> List (Errors.Errors Problem) -> Element Msg
viewAvailableSeatingInput seats problems =
    let
        errorMapper =
            Errors.inputErrorsFor problems
    in
    StyledElement.numberInput
        [ width
            (fill
                |> maximum 300
            )
        , alignTop
        ]
        { ariaLabel = "How many seats are available for students on the bus?"
        , caption = Just "How many seats are available for students on the bus?"
        , errorCaption =
            errorMapper "seats_available" []
        , icon = Nothing
        , onChange = SeatsAvailable >> Changed
        , placeholder = Nothing
        , title = "Student Seats"
        , value = seats
        , maximum = Just 70
        , minimum = Just 3
        }


viewDivider : Element Msg
viewDivider =
    el
        [ width fill
        , height (px 1)
        , Background.color (rgba 0 0 0 0.1)
        ]
        none


viewVerticalDivider : Element Msg
viewVerticalDivider =
    el
        [ height fill
        , width (px 2)
        , Background.color (rgba 0 0 0 0.1)
        ]
        none


viewButton : WebData a -> Element Msg
viewButton requestState =
    let
        buttonView =
            case requestState of
                Loading ->
                    Icons.loading [ alignRight, width (px 46), height (px 46) ]

                _ ->
                    StyledElement.button [ alignRight ]
                        { onPress = Just SubmitButtonMsg
                        , label = text "Submit"
                        }
    in
    el (Style.labelStyle ++ [ width fill, paddingEach { edges | right = 24 } ])
        buttonView


consumptionDropDown : Model -> ( Element Msg, Dropdown.Config ConsumptionType Msg, List ConsumptionType )
consumptionDropDown model =
    let
        vehicleClass =
            model.form.vehicleClass

        justConsumptionType x =
            Maybe.withDefault Default x
    in
    StyledElement.dropDown
        [ width
            (fill
                |> maximum 300
            )
        , alignTop
        ]
        { ariaLabel = "Select the consumption rate of the vehicle in kilometers per litre"
        , caption = Nothing
        , dropDownMsg = ConsumptionDropdownMsg
        , dropdownState = model.consumptionDropdownState
        , errorCaption = Nothing
        , icon = Nothing
        , onSelect = justConsumptionType >> FuelConsumptionType >> Changed
        , options = [ Default, Custom ]
        , title = "Fuel Consumption per Kilometer"
        , prompt = Nothing
        , toString =
            \x ->
                case x of
                    Custom ->
                        "Custom Mileage"

                    Default ->
                        "Default - " ++ String.fromFloat (defaultConsumption vehicleClass) ++ " Km / Litre"
        , isLoading = False
        }


viewConsumptionDropDown : Model -> Element Msg
viewConsumptionDropDown model =
    case consumptionDropDown model of
        ( dropDown, _, _ ) ->
            dropDown


viewConsumptionInput : FloatInput -> Element Msg
viewConsumptionInput consumptionAmount =
    FloatInput.view
        [ width
            (fill
                |> maximum 300
            )
        , alignTop
        ]
        { ariaLabel = "What is the vehicle's mileage?"
        , caption = Nothing
        , errorCaption = Nothing
        , icon = Nothing
        , onChange = FuelConsumptionAmount >> Changed
        , placeholder = Nothing
        , title = "Custom Mileage (Km / Litre)"
        , value = consumptionAmount
        , minimum = Just 0
        , maximum = Just 30
        }


fuelDropDown : Model -> ( Element Msg, Dropdown.Config FuelType Msg, List FuelType )
fuelDropDown model =
    let
        problems =
            model.form.problems

        errorMapper =
            Errors.inputErrorsFor model.form.problems

        justFuelType x =
            Maybe.withDefault (toFuelType model.form.vehicleClass) x
    in
    StyledElement.dropDown
        [ width
            (fill
                |> maximum 300
            )
        , alignTop
        ]
        { ariaLabel = "Select fuel type"
        , caption = Nothing
        , prompt = Nothing
        , dropDownMsg = FuelDropdownMsg
        , dropdownState = model.fuelDropdownState
        , errorCaption =
            errorMapper "fuel_type" []

        -- , errorCaption = Nothing
        , icon = Just Icons.fuel
        , onSelect = justFuelType >> FuelType >> Changed
        , options = [ Diesel, Gasoline ]
        , title = "Fuel Type"
        , toString =
            \x ->
                case x of
                    Diesel ->
                        "Diesel"

                    Gasoline ->
                        "Gasoline"
        , isLoading = False
        }


viewFuelTypeDropDown : Model -> Element Msg
viewFuelTypeDropDown model =
    toDropDownView (fuelDropDown model)


routeDropDown : Model -> ( Element Msg, Dropdown.Config String Msg, List String )
routeDropDown model =
    StyledElement.dropDown
        [ width
            (fill
                |> maximum 300
            )
        , alignTop
        ]
        { ariaLabel = "Select bus dropdown"
        , caption = Just "Which route will the bus ply?"
        , prompt = Nothing
        , dropDownMsg = RouteDropdownMsg
        , dropdownState = model.routeDropdownState
        , errorCaption = Nothing
        , icon = Just Icons.timeline
        , onSelect = Route >> Changed
        , options = [ "a", "b", "c", "d", "e", "f" ]
        , title = "Route"
        , toString = identity
        , isLoading = False
        }


viewRouteDropDown : Model -> Element Msg
viewRouteDropDown model =
    case routeDropDown model of
        ( dropDown, _, _ ) ->
            dropDown


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        []


defaultConsumption : VehicleClass -> Float
defaultConsumption vehicleClass =
    case vehicleClass of
        VehicleClass Van Gasoline ->
            7.4

        VehicleClass Van Diesel ->
            8.1

        VehicleClass Shuttle Gasoline ->
            3.3

        VehicleClass Shuttle Diesel ->
            3.3

        VehicleClass SchoolBus Gasoline ->
            2.7

        VehicleClass SchoolBus Diesel ->
            3.0


defaultSeats : VehicleClass -> Int
defaultSeats vehicleClass =
    case vehicleClass of
        VehicleClass Van _ ->
            12

        VehicleClass Shuttle _ ->
            24

        VehicleClass SchoolBus _ ->
            48


toVehicleType : VehicleClass -> VehicleType
toVehicleType class =
    case class of
        VehicleClass vehicleType _ ->
            vehicleType


toFuelType : VehicleClass -> FuelType
toFuelType class =
    case class of
        VehicleClass _ fuelType ->
            fuelType


vehicleTypeToIcon : VehicleType -> Icons.IconBuilder msg
vehicleTypeToIcon vehicleType =
    case vehicleType of
        Van ->
            Icons.van

        Shuttle ->
            Icons.shuttle

        SchoolBus ->
            Icons.bus


validateForm : Form -> Result (List ( Problem, String )) ValidForm
validateForm form =
    let
        problems =
            if Validator.isValidNumberPlate form.numberPlate then
                []

            else
                [ ( InvalidNumberPlate, "There's something wrong with this number plate" ) ]

        vehicleType =
            toVehicleType form.vehicleClass
                |> Models.Bus.vehicleTypeToString

        fuelType =
            case toFuelType form.vehicleClass of
                Diesel ->
                    "diesel"

                Gasoline ->
                    "gasoline"
    in
    case problems of
        [] ->
            Ok
                { vehicleType = vehicleType
                , numberPlate = form.numberPlate
                , seatsAvailable = form.seatsAvailable
                , routeId = Nothing
                , consumptionAmount = FloatInput.toFloat form.consumptionAmount
                , fuelType = fuelType
                }

        _ ->
            Err problems


submit : Session -> ValidForm -> Cmd Msg
submit session form =
    let
        params =
            Encode.object
                [ ( "number_plate", Encode.string form.numberPlate )
                , ( "seats_available", Encode.int form.seatsAvailable )
                , ( "vehicle_type", Encode.string form.vehicleType )
                , ( "stated_milage", Encode.float form.consumptionAmount )
                , ( "fuel_type", Encode.string form.fuelType )
                ]
                |> Http.jsonBody
    in
    Api.post session Endpoint.buses params busDecoder
        |> Cmd.map ServerResponse


busDecoder : Decoder Int
busDecoder =
    field "id" int
