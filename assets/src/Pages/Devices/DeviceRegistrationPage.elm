module Pages.Devices.DeviceRegistrationPage exposing (Model, Msg, init, subscriptions, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Errors exposing (InputError)
import Html exposing (Html)
import Html.Attributes exposing (id)
import Html.Events exposing (..)
import Http
import Icons
import Json.Decode as Decode exposing (Decoder, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required, resolve)
import Json.Encode as Encode
import Ports
import RemoteData exposing (..)
import Route
import Session exposing (Session)
import Style
import StyledElement exposing (toDropDownView, wrappedInput)
import Utils.Validator as Validator
import Views.CustomDropDown as Dropdown
import Views.Heading exposing (viewHeading)



-- MODEL


type alias Model =
    { session : Session
    , form : Form
    , cameraState : CameraState
    , busDropDownState : Dropdown.State Bus
    , buses : WebData (List Bus)
    , requestState : WebData ValidForm
    }


type Problem
    = InvalidIMEI
    | CameraOpenError
    | ServerError String (List String)


type alias Bus =
    { id : Int
    , numberPlate : String
    , hasDevice : Bool
    }


type CameraState
    = CameraOpening
    | CameraClosed
    | CameraOpen
    | CameraClosing


type alias Form =
    { imei : String
    , selectedBus : Maybe Bus
    , problems : List (Errors.Errors Problem)

    -- , problems : List Problem
    -- , serverErrors : List ( String, List String )
    }


type alias ValidForm =
    { imei : String
    , bus_id : Maybe Int
    }


type Msg
    = ChangedDeviceIMEI String
    | SubmitButtonMsg
    | BusesServerResponse (WebData (List Bus))
    | RegisterResponse (WebData ValidForm)
    | ToggleCamera
    | CameraOpened Bool
    | GotCameraNotFoundError
    | ReceivedCode String
    | BusPicked (Maybe Bus)
    | DropdownMsg (Dropdown.Msg Bus)


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , form =
            { imei = ""
            , selectedBus = Nothing
            , problems = []
            }
      , cameraState = CameraClosed
      , busDropDownState = Dropdown.init "busDropDownState"
      , buses = Loading
      , requestState = NotAsked
      }
    , Cmd.batch [ fetchBuses session ]
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form
    in
    case msg of
        ChangedDeviceIMEI imei ->
            let
                updated_form =
                    { form | imei = imei }
            in
            ( { model | form = updated_form }, Cmd.none )

        SubmitButtonMsg ->
            case validateForm model.form of
                Ok validForm ->
                    ( { model
                        | form = { form | problems = [] }
                        , requestState = Loading
                      }
                    , submit model.session validForm
                    )

                Err problems ->
                    ( { model
                        | form =
                            { form
                                | problems = Errors.toClientSideErrors problems
                            }
                      }
                    , Cmd.none
                    )

        ToggleCamera ->
            if model.cameraState == CameraClosed then
                ( { model
                    | cameraState = CameraOpening
                    , form =
                        { form
                            | problems = List.filter (\x -> x /= Errors.ClientSideError CameraOpenError "") model.form.problems
                        }
                  }
                , Ports.initializeCamera ()
                )

            else
                ( model, Ports.disableCamera 0 )

        CameraOpened isActive ->
            ( { model
                | cameraState =
                    if isActive then
                        CameraOpen

                    else
                        CameraClosed
              }
            , Cmd.none
            )

        GotCameraNotFoundError ->
            let
                newError =
                    Errors.toClientSideError
                        ( CameraOpenError, "No webcam found, type in the code or try again later" )
            in
            ( { model
                | form =
                    { form
                        | problems =
                            if List.member newError form.problems then
                                form.problems

                            else
                                newError :: form.problems
                    }
              }
            , Cmd.none
            )

        ReceivedCode scannedIMEI ->
            let
                updated_form =
                    { form | imei = scannedIMEI }
            in
            if Validator.isValidImei scannedIMEI then
                ( { model | form = updated_form, cameraState = CameraClosing }
                , Cmd.batch
                    [ Ports.disableCamera 1500
                    , Ports.setFrameFrozen True
                    ]
                )

            else
                ( { model | form = { form | imei = "" } }
                , Cmd.batch
                    [ Ports.setFrameFrozen False
                    ]
                )

        BusPicked bus ->
            ( { model | form = { form | selectedBus = bus } }, Cmd.none )

        DropdownMsg subMsg ->
            let
                ( _, config, options ) =
                    busDropdown model

                ( state, cmd ) =
                    Dropdown.update config subMsg model.busDropDownState options
            in
            ( { model | busDropDownState = state }, cmd )

        BusesServerResponse response ->
            case response of
                Success buses ->
                    let
                        filteredBuses =
                            buses
                                |> List.filter (.hasDevice >> not)
                                |> List.sortBy .numberPlate
                                |> Success
                    in
                    ( { model | buses = filteredBuses }, Cmd.none )

                _ ->
                    ( { model | buses = response }, Cmd.none )

        RegisterResponse response ->
            let
                newModel =
                    { model | requestState = response }
            in
            case response of
                Success _ ->
                    ( newModel, Route.rerouteTo newModel Route.DeviceList )

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



-- VIEW


view : Model -> Element Msg
view model =
    row [ width fill, height fill, spaceEvenly ]
        [ viewBody model
        , viewScanExplanation
        ]


viewBody : Model -> Element Msg
viewBody model =
    Element.column
        [ width fill, spacing 40, paddingXY 24 8, alignTop ]
        [ viewHeading "Register Your Device" Nothing
        , viewForm model
        ]


viewForm : Model -> Element Msg
viewForm model =
    let
        form =
            model.form
    in
    Element.column
        [ width shrink, spacing 36 ]
        [ if model.cameraState /= CameraClosed then
            viewScanner model.cameraState

          else
            none
        , row [ spacing 36, width shrink, height shrink ]
            [ viewDeviceIMEIInput form.imei form.problems
            , Input.button [ padding 8, centerY, Background.color Colors.purple, Border.rounded 8 ]
                { label =
                    el []
                        (if model.cameraState /= CameraClosed then
                            Icons.cameraOff []

                         else
                            Icons.camera []
                        )
                , onPress = Just ToggleCamera
                }
            ]
        , toDropDownView <| busDropdown model
        , viewButton
        ]


viewScanner : CameraState -> Element Msg
viewScanner cameraState =
    let
        cameraStyle =
            if cameraState /= CameraClosed then
                [ Border.color (rgb255 97 165 145)
                , moveUp 2
                , Border.shadow { offset = ( 0, 12 ), blur = 20, size = 0, color = rgba255 0 0 0 0.3 }
                ]

            else
                [ Border.color (rgba255 197 197 197 0.5)
                ]
    in
    row [ width fill, spacing 20 ]
        [ el
            ([ width shrink
             , height shrink
             , Background.color (rgb 0 0 0)
             , Border.solid
             , Border.width 1
             , Border.color Colors.purple
             , inFront
                (if cameraState == CameraClosing then
                    -- Animate closing
                    el [ width fill, height fill, Background.color (rgba 0 0 0 0.7) ]
                        (Icons.loading [ centerX, centerY, width (px 46), height (px 46) ])

                 else
                    none
                )
             ]
                ++ (if cameraState /= CameraOpening then
                        [ Style.animatesAllDelayed ]

                    else
                        []
                   )
                ++ cameraStyle
            )
            (column [ width shrink ]
                [ html
                    (Html.canvas
                        [ id "camera-canvas"
                        , Html.Attributes.height 0
                        , Html.Attributes.width 0
                        , Html.Attributes.autoplay True
                        ]
                        []
                    )
                , el
                    ([ height (px 4)
                     , alignBottom
                     , alignLeft
                     , Background.color Colors.teal
                     ]
                        ++ (if cameraState == CameraOpen then
                                [ width fill, Style.animatesAll20Seconds ]

                            else
                                [ width (px 0), Style.animatesAll ]
                           )
                    )
                    none
                ]
            )
        ]


viewDeviceIMEIInput : String -> List (Errors.Errors Problem) -> Element Msg
viewDeviceIMEIInput imei problems =
    let
        errorMapper =
            Errors.inputErrorsFor problems

        inputError errorText =
            Errors.InputError [ errorText ]
    in
    StyledElement.textInput
        [ width
            (fill
                |> maximum 300
            )
        , alignTop
        ]
        { ariaLabel = "Device Serial"
        , caption = Just "You can find this on the side of the device"
        , errorCaption =
            errorMapper "imei"
                [ InvalidIMEI
                , CameraOpenError
                ]
        , icon = Nothing
        , onChange = ChangedDeviceIMEI
        , placeholder = Nothing
        , title = "Device Serial"
        , value = imei
        }


viewDivider =
    el
        [ width (fill |> minimum 20 |> maximum 480)
        , height (px 1)
        , Background.color (rgb255 243 243 243)
        ]
        none


viewButton : Element Msg
viewButton =
    StyledElement.button [ alignRight ]
        { onPress = Just SubmitButtonMsg
        , label = text "Register"
        }


busDropdown : Model -> ( Element Msg, Dropdown.Config Bus Msg, List Bus )
busDropdown model =
    let
        dropdown buses =
            StyledElement.dropDown []
                { ariaLabel = "Select bus dropdown"
                , caption = Just "Select the bus you will attach the device to"
                , dropDownMsg = DropdownMsg
                , dropdownState = model.busDropDownState
                , errorCaption = Nothing
                , icon = Just Icons.shuttle
                , onSelect = BusPicked
                , options = buses
                , title = "Bus"
                , toString = \x -> x.numberPlate
                }
    in
    case model.buses of
        Success buses ->
            dropdown buses

        _ ->
            dropdown []


viewScanExplanation =
    column [ padding 24, spacing 20 ]
        [ Icons.qrBox []
        , column (centerX :: Style.labelStyle) [ el [ centerX ] (text "If you have a webcam,"), el [ centerX ] (text "you can scan the QR Code on the side of the box") ]
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.receiveCameraActive CameraOpened
        , Ports.scannedDeviceCode ReceivedCode
        , Ports.noCameraFoundError (\_ -> GotCameraNotFoundError)
        ]


fetchBuses : Session -> Cmd Msg
fetchBuses session =
    Api.get session Endpoint.buses (list busDecoder)
        |> Cmd.map BusesServerResponse


busDecoder : Decoder Bus
busDecoder =
    let
        toBus : Int -> String -> Maybe String -> Decoder Bus
        toBus id number_plate device =
            Decode.succeed
                { id = id
                , numberPlate = number_plate
                , hasDevice = device /= Nothing
                }
    in
    Decode.succeed toBus
        |> required "id" int
        |> required "number_plate" string
        |> required "device" (nullable string)
        |> resolve


validateForm : Form -> Result (List ( Problem, String )) ValidForm
validateForm form =
    let
        problems =
            if Validator.isValidImei form.imei then
                []

            else
                [ ( InvalidIMEI, "This value does not have the correct format, please enter it again" ) ]
    in
    case problems of
        [] ->
            Ok
                { imei = form.imei
                , bus_id = Maybe.map .id form.selectedBus
                }

        _ ->
            Err problems


submit : Session -> ValidForm -> Cmd Msg
submit session form =
    let
        params =
            (case form.bus_id of
                Just bus_id ->
                    Encode.object
                        [ ( "bus_id", Encode.int bus_id )
                        ]

                Nothing ->
                    Encode.object []
            )
                |> Http.jsonBody
    in
    Api.patch session (Endpoint.registerDevice form.imei) params (Decode.succeed form)
        |> Cmd.map RegisterResponse
