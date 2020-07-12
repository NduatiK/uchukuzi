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
import Element.Events
import Element.Font as Font
import Element.Input as Input
import Errors
import Html.Events exposing (..)
import Icons
import Json.Decode exposing (Decoder, field, float, int, list, string)
import Json.Encode as Encode
import Layout.TabBar as TabBar exposing (TabBarItem(..))
import Models.Bus exposing (..)
import Navigation
import Pages.Buses.Bus.Navigation exposing (BusPage(..))
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import StyledElement.DropDown as Dropdown
import StyledElement.FloatInput as FloatInput exposing (FloatInput)
import StyledElement.WebDataView as WebDataView
import Task
import Utils.Validator as Validator



-- MODEL


type alias Model =
    { session : Session
    , busID : Maybe Int
    , form : Form
    , routeDropdownState : Dropdown.State SimpleRoute
    , requestState : WebData Int
    , routeRequestState : WebData (List SimpleRoute)
    , editRequestState : WebData Form
    }


type alias Form =
    { vehicleType : VehicleType
    , numberPlate : String
    , seatsAvailable : Int
    , routeId : Maybe Int
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
    }


type Field
    = VehicleType VehicleType
    | NumberPlate String
    | SeatsAvailable Int
    | Route (Maybe Int)


emptyForm : Maybe Int -> Session -> Model
emptyForm busID session =
    let
        defaultVehicle =
            SchoolBus
    in
    { session = session
    , busID = busID
    , form =
        { vehicleType = defaultVehicle
        , numberPlate = ""
        , seatsAvailable = defaultSeats defaultVehicle
        , routeId = Nothing
        , problems = []
        }
    , routeDropdownState = Dropdown.init "routeDropdown"
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
        ]
    )



-- UPDATE


type Msg
    = Changed Field
    | SubmitButtonMsg
    | ReceivedCreateResponse (WebData Int)
    | ReceivedRouteResponse (WebData (List SimpleRoute))
    | ReceivedEditResponse (WebData ( Form, Cmd Msg ))
    | RouteDropdownMsg (Dropdown.Msg SimpleRoute)
    | ReturnToBusList
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

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
                    ( { model | form = { form | problems = Errors.toValidationErrors problems } }, Cmd.none )

        ReceivedEditResponse response_ ->
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

        ReceivedCreateResponse response ->
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
                        apiFormError =
                            Errors.toServerSideErrors error

                        updatedForm =
                            { form | problems = form.problems ++ apiFormError }
                    in
                    ( { newModel | form = updatedForm }, Errors.toMsg error )

                _ ->
                    ( { newModel | form = { form | problems = [] } }, Cmd.none )

        ReceivedRouteResponse response ->
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
                updated_form =
                    { form
                        | vehicleType = vehicleType
                        , seatsAvailable = defaultSeats vehicleType
                    }
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



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    row [ width fill, height (fill |> maximum viewHeight), scrollbarY ]
        [ viewBody model
        ]


viewBody : Model -> Element Msg
viewBody model =
    Element.column
        [ width fill, spacing 40, padding 30, alignTop ]
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
                [ viewTypePicker form.vehicleType
                , viewDivider
                , wrappedRow [ spaceEvenly, width fill ]
                    [ column
                        [ spacing 32, width (fill |> minimum 300 |> maximum 300), alignTop ]
                        [ viewNumberPlateInput form.numberPlate form.problems
                        , viewAvailableSeatingInput form.seatsAvailable form.problems
                        ]
                    , viewVerticalDivider
                    , column
                        [ spacing 32, width (fill |> minimum 300 |> maximum 300), alignTop ]
                        [ Dropdown.viewFromModel model routeDropDown
                        , viewButton model.requestState
                        ]
                    ]
                ]
        )


viewTypePicker : VehicleType -> Element Msg
viewTypePicker vehicleType =
    wrappedRow [ spacing 32 ]
        [ viewVehicle SchoolBus vehicleType
        , viewVehicle Shuttle vehicleType
        , viewVehicle Van vehicleType
        ]


viewVehicle : VehicleType -> VehicleType -> Element Msg
viewVehicle vehicleType currentType =
    let
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
            Errors.captionFor problems
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
            Errors.captionFor problems
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
        ([ width
            (fill
                |> maximum 300
            )
         , alignTop
         ]
            ++ (if routes == [] then
                    [ Style.clickThrough
                    , inFront
                        (el
                            [ centerX
                            , alpha 0
                            , width (fill |> maximum 310)
                            , height fill
                            , mouseOver [ alpha 1 ]
                            ]
                            (paragraph
                                ([ Background.color Colors.white
                                 , Style.elevated2
                                 , moveDown 100
                                 , Border.color Colors.darkGreen
                                 , Border.width 1
                                 , padding 8
                                 ]
                                    ++ Style.captionStyle
                                )
                                [ text "You have not created any routes yet, you can leave this blank and add one later" ]
                            )
                        )
                    ]

                else
                    []
               )
        )
        { ariaLabel = "Select bus dropdown"
        , caption = Just "Which route will the bus ply?"
        , prompt = Nothing
        , dropDownMsg = RouteDropdownMsg
        , dropdownState = model.routeDropdownState
        , errorCaption = Nothing
        , icon = Just Icons.pin
        , onSelect = Maybe.map .id >> Route >> Changed
        , options = routes
        , title = "Route"
        , toString = .name
        , isLoading = False
        }


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
            form.vehicleType
                |> Models.Bus.vehicleTypeToString
    in
    case problems of
        [] ->
            Ok
                { vehicleType = vehicleType
                , numberPlate = form.numberPlate
                , seatsAvailable = form.seatsAvailable
                , routeId = form.routeId
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
                 ]
                    ++ (form.routeId
                            |> Maybe.map (\routeId -> [ ( "route_id", Encode.int routeId ) ])
                            |> Maybe.withDefault []
                       )
                )
    in
    case ( isEditing model, model.busID ) of
        ( True, Just busID ) ->
            Api.patch session (Endpoint.bus busID) params busDecoder
                |> Cmd.map ReceivedCreateResponse

        _ ->
            Api.post session Endpoint.buses params busDecoder
                |> Cmd.map ReceivedCreateResponse


busDecoder : Decoder Int
busDecoder =
    field "id" int


fetchRoutes : Maybe Int -> Session -> Cmd Msg
fetchRoutes busID session =
    Api.get session (Endpoint.routesAvailableForBus busID) (list simpleRouteDecoder)
        |> Cmd.map ReceivedRouteResponse


fetchBus : Int -> Session -> Cmd Msg
fetchBus busID session =
    Api.get session (Endpoint.bus busID) (busDecoderWithCallback busToForm)
        |> Cmd.map ReceivedEditResponse


busToForm : Bus -> ( Form, Cmd Msg )
busToForm bus =
    ( { vehicleType = bus.vehicleType
      , numberPlate = bus.numberPlate
      , seatsAvailable = bus.seatsAvailable
      , routeId = Nothing
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
            ]

        Failure _ ->
            [ TabBar.Button
                { title = "Cancel"
                , icon = Icons.cancel
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
                , icon = Icons.cancel
                , onPress = ReturnToBusList
                }
            , TabBar.Button
                { title = "Save"
                , icon = Icons.save
                , onPress = SubmitButtonMsg
                }
            ]
