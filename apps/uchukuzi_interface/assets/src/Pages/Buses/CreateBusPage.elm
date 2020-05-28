module Pages.Buses.CreateBusPage exposing
    ( Model
    , Msg
    , init
    , initEdit
    , subscriptions
    , tabBarItems
    , update
    , view
    )

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
import Icons
import Json.Decode exposing (Decoder, field, float, int, list, string)
import Json.Encode as Encode
import Models.Bus exposing (..)
import Navigation
import Pages.Buses.Bus.Navigation exposing (BusPage(..))
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement exposing (toDropDownView)
import StyledElement.DropDown as Dropdown
import StyledElement.FloatInput as FloatInput exposing (FloatInput)
import StyledElement.WebDataView as WebDataView
import Task
import Template.TabBar as TabBar exposing (TabBarItem(..))
import Utils.Validator as Validator



-- MODEL


type alias Model =
    { session : Session
    , busID : Maybe Int
    , form : Form
    , routeDropdownState : Dropdown.State SimpleRoute
    , fuelDropdownState : Dropdown.State FuelType
    , consumptionDropdownState : Dropdown.State ConsumptionType
    , requestState : WebData Int
    , routeRequestState : WebData (List SimpleRoute)
    , editRequestState : WebData Form
    }


type alias Form =
    { vehicleClass : VehicleClass
    , numberPlate : String
    , seatsAvailable : Int
    , routeId : Maybe Int
    , consumptionType : ConsumptionType
    , consumptionAmount : FloatInput
    , problems : List (Errors.Errors Problem)
    }


type Problem
    = InvalidNumberPlate
    | EmptyRoute


type alias ValidForm =
    { vehicleType : String
    , numberPlate : String
    , seatsAvailable : Int
    , routeId : Maybe Int
    , consumptionAmount : Float
    , fuelType : String
    }


type ConsumptionType
    = Custom
    | Default


type Field
    = VehicleType VehicleType
    | FuelType FuelType
    | NumberPlate String
    | SeatsAvailable Int
    | Route (Maybe Int)
    | FuelConsumptionType ConsumptionType
    | FuelConsumptionAmount FloatInput


emptyForm : Maybe Int -> Session -> Model
emptyForm busID session =
    let
        defaultVehicle =
            VehicleClass SchoolBus Diesel
    in
    { session = session
    , busID = busID
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
    , editRequestState = NotAsked
    , routeRequestState = Loading
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( emptyForm Nothing session
    , Cmd.batch
        [ Ports.initializeMaps
        , fetchRoutes Nothing session
        , Task.succeed (FuelDropdownMsg (Dropdown.selectOption Diesel)) |> Task.perform identity
        , Task.succeed (ConsumptionDropdownMsg (Dropdown.selectOption Default)) |> Task.perform identity
        ]
    )


initEdit : Int -> Session -> ( Model, Cmd Msg )
initEdit busID session =
    let
        defaultModel =
            emptyForm (Just busID) session
    in
    ( { defaultModel | editRequestState = Loading }
    , Cmd.batch
        [ Ports.initializeMaps
        , fetchBus busID session
        , fetchRoutes (Just busID) session
        , Task.succeed (FuelDropdownMsg (Dropdown.selectOption Diesel)) |> Task.perform identity
        , Task.succeed (ConsumptionDropdownMsg (Dropdown.selectOption Default)) |> Task.perform identity
        ]
    )



-- UPDATE


type Msg
    = Changed Field
    | SubmitButtonMsg
    | ServerResponse (WebData Int)
    | RouteServerResponse (WebData (List SimpleRoute))
    | EditServerResponse (WebData ( Form, Cmd Msg ))
    | RouteDropdownMsg (Dropdown.Msg SimpleRoute)
    | FuelDropdownMsg (Dropdown.Msg FuelType)
    | ConsumptionDropdownMsg (Dropdown.Msg ConsumptionType)
    | ReturnToBusList


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReturnToBusList ->
            ( model, Navigation.rerouteTo model Navigation.Buses )

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
                    , submit model model.session validForm
                    )

                Err problems ->
                    ( { model | form = { form | problems = Errors.toClientSideErrors problems } }, Cmd.none )

        EditServerResponse response_ ->
            let
                ( response, cmd ) =
                    case response_ of
                        Success ( form, cmd_ ) ->
                            ( Success form, cmd_ )

                        Failure e ->
                            ( Failure e, Cmd.none )

                        Loading ->
                            ( Loading, Cmd.none )

                        NotAsked ->
                            ( NotAsked, Cmd.none )

                newModel =
                    { model | editRequestState = response }
            in
            case response of
                Success form ->
                    ( { newModel | form = form }, cmd )

                _ ->
                    ( newModel, Cmd.none )

        ServerResponse response ->
            let
                newModel =
                    { model | requestState = response }

                form =
                    newModel.form
            in
            case response of
                Success bus_id ->
                    ( newModel, Navigation.rerouteTo newModel (Navigation.Bus bus_id About) )

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

        RouteServerResponse response ->
            case response of
                Success routes ->
                    let
                        match =
                            List.head (List.filter (\route -> route.busID == model.busID) routes)
                    in
                    case match of
                        Just route ->
                            ( { model | routeRequestState = response }
                            , Task.succeed (RouteDropdownMsg (Dropdown.selectOption route)) |> Task.perform identity
                            )

                        _ ->
                            ( { model | routeRequestState = response }, Cmd.none )

                _ ->
                    ( { model | routeRequestState = response }, Cmd.none )


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
                    VehicleClass vehicleType (vehicleClassToFuelType form.vehicleClass)

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
                    { form | vehicleClass = VehicleClass (vehicleClassToType form.vehicleClass) fuelType }
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


view : Model -> Int -> Element Msg
view model viewHeight =
    row [ width fill, height (fill |> maximum viewHeight), scrollbarY ]
        [ viewBody model
        ]


viewBody : Model -> Element Msg
viewBody model =
    Element.column
        [ width fill, spacing 40, paddingEach { edges | left = 50, right = 30, top = 30, bottom = 30 }, alignTop ]
        [ viewHeading
            (if isEditing model then
                "Edit Vehicle"

             else
                "Add a Vehicle"
            )
        , viewForm model
        ]


viewHeading : String -> Element msg
viewHeading title =
    Element.column
        [ width fill ]
        [ el Style.headerStyle (text title)
        ]


viewForm : Model -> Element Msg
viewForm model =
    let
        form =
            model.form
    in
    WebDataView.view model.routeRequestState
        (\routes ->
            column
                [ spacing 50, paddingEach { edges | bottom = 100 }, centerX ]
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
                        , viewButton model.requestState
                        ]
                    ]
                ]
        )


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
            vehicleClassToType currentClass

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
    none



-- let
--     buttonView =
--         case requestState of
--             Loading ->
--                 Icons.loading [ alignRight, width (px 46), height (px 46) ]
--             _ ->
--                 StyledElement.button [ alignRight ]
--                     { onPress = Just SubmitButtonMsg
--                     , label = text "Save"
--                     }
-- in
-- el (Style.labelStyle ++ [ width fill, paddingEach { edges | right = 24 } ])
--     buttonView


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
            Maybe.withDefault (vehicleClassToFuelType model.form.vehicleClass) x
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


routeDropDown : Model -> ( Element Msg, Dropdown.Config SimpleRoute Msg, List SimpleRoute )
routeDropDown model =
    let
        routes =
            case model.routeRequestState of
                Success routes_ ->
                    -- List.filter (\r -> r.bus == Nothing) routes_
                    routes_

                _ ->
                    []
    in
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
        , icon = Just Icons.pin
        , onSelect = Maybe.andThen (.id >> Just) >> Route >> Changed
        , options = routes
        , title = "Route"
        , toString = .name
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


validateForm : Form -> Result (List ( Problem, String )) ValidForm
validateForm form =
    let
        problems =
            List.concat
                [ if Validator.isValidNumberPlate form.numberPlate then
                    []

                  else
                    [ ( InvalidNumberPlate, "There's something wrong with this number plate" ) ]

                -- , if form.routeId == Nothing then
                --     [ ( EmptyRoute, "Please se" ) ]
                --   else
                --     []
                ]

        vehicleType =
            vehicleClassToType form.vehicleClass
                |> Models.Bus.vehicleTypeToString

        fuelType =
            case vehicleClassToFuelType form.vehicleClass of
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
                , routeId = form.routeId
                , consumptionAmount = FloatInput.toFloat form.consumptionAmount
                , fuelType = fuelType
                }

        _ ->
            Err problems


submit : Model -> Session -> ValidForm -> Cmd Msg
submit model session form =
    let
        params =
            Encode.object
                ([ ( "number_plate", Encode.string form.numberPlate )
                 , ( "seats_available", Encode.int form.seatsAvailable )
                 , ( "vehicle_type", Encode.string form.vehicleType )
                 , ( "stated_milage", Encode.float form.consumptionAmount )
                 , ( "fuel_type", Encode.string form.fuelType )
                 ]
                    ++ Maybe.withDefault []
                        (Maybe.andThen (\routeId -> Just [ ( "route_id", Encode.int routeId ) ]) form.routeId)
                )
    in
    case ( isEditing model, model.busID ) of
        ( True, Just busID ) ->
            Api.patch session (Endpoint.bus busID) params busDecoder
                |> Cmd.map ServerResponse

        _ ->
            Api.post session Endpoint.buses params busDecoder
                |> Cmd.map ServerResponse


busDecoder : Decoder Int
busDecoder =
    field "id" int


fetchRoutes : Maybe Int -> Session -> Cmd Msg
fetchRoutes busID session =
    Api.get session (Endpoint.routesAvailableForBus busID) (list simpleRouteDecoder)
        |> Cmd.map RouteServerResponse


fetchBus : Int -> Session -> Cmd Msg
fetchBus busID session =
    Api.get session (Endpoint.bus busID) (busDecoderWithCallback busToForm)
        |> Cmd.map EditServerResponse


busToForm : Bus -> ( Form, Cmd Msg )
busToForm bus =
    ( { vehicleClass = bus.vehicleClass
      , numberPlate = bus.numberPlate
      , seatsAvailable = bus.seatsAvailable
      , routeId = Nothing
      , consumptionType = Custom
      , consumptionAmount = FloatInput.fromFloat bus.statedMilage
      , problems = []
      }
    , case bus.route of
        Just route ->
            Task.succeed (RouteDropdownMsg (Dropdown.selectOption route)) |> Task.perform identity

        Nothing ->
            Cmd.none
    )


isEditing model =
    model.editRequestState /= NotAsked


tabBarItems { requestState } =
    case requestState of
        Loading ->
            [ TabBar.LoadingButton
                { title = ""
                }
            ]

        Failure _ ->
            [ TabBar.Button
                { title = "Cancel"
                , icon = Icons.close
                , onPress = ReturnToBusList
                }
            , TabBar.ErrorButton
                { title = "Try Again"
                , icon = Icons.save
                , onPress = SubmitButtonMsg
                }
            ]

        _ ->
            [ TabBar.Button
                { title = "Cancel"
                , icon = Icons.close
                , onPress = ReturnToBusList
                }
            , TabBar.Button
                { title = "Save"
                , icon = Icons.save
                , onPress = SubmitButtonMsg
                }
            ]
