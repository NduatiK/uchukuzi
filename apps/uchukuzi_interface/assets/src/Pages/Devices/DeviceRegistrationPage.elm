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
import Icons
import Json.Decode as Decode exposing (Decoder, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required, resolve)
import Json.Encode as Encode
import Navigation
import Pages.Buses.Bus.Navigation exposing (BusPage(..))
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style
import StyledElement exposing (wrappedInput)
import StyledElement.DropDown as Dropdown
import Utils.Validator as Validator



-- MODEL


type alias Model =
    { session : Session
    , form : Form
    , cameraState : CameraState
    , requestState : WebData ValidForm
    , bus : Int
    }


type alias Form =
    { serial : String
    , problems : List (Errors.Errors Problem)
    }


type Problem
    = InvalidSerial
    | CameraOpenError
    | ServerError String (List String)


type CameraState
    = CameraOpening
    | CameraClosed
    | CameraOpen
    | CameraClosing


type alias ValidForm =
    { serial : String
    , bus_id : Int
    }


type Msg
    = ChangedDeviceSerial String
    | SubmitButtonMsg
    | RegisterResponse (WebData ValidForm)
    | ToggleCamera
    | CameraOpened Bool
    | GotCameraNotFoundError
    | ReceivedCode String


init : Session -> Int -> ( Model, Cmd Msg )
init session busID =
    ( { session = session
      , bus = busID
      , form =
            { serial = ""
            , problems = []
            }
      , cameraState = CameraClosed
      , requestState = NotAsked
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form
    in
    case msg of
        ChangedDeviceSerial serial ->
            let
                updated_form =
                    { form | serial = serial }
            in
            ( { model | form = updated_form }, Cmd.none )

        SubmitButtonMsg ->
            case validateForm model of
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

        ReceivedCode scannedSerial ->
            let
                updated_form =
                    { form | serial = scannedSerial }
            in
            if Validator.isValidImei scannedSerial then
                ( { model | form = updated_form, cameraState = CameraClosing }
                , Cmd.batch
                    [ Ports.disableCamera 500
                    , Ports.setFrameFrozen True
                    ]
                )

            else
                ( { model | form = { form | serial = "" } }
                , Cmd.batch
                    [ Ports.setFrameFrozen False
                    ]
                )

        RegisterResponse response ->
            let
                newModel =
                    { model | requestState = response }
            in
            case response of
                Success _ ->
                    ( newModel, Navigation.rerouteTo newModel (Navigation.Bus model.bus BusDevice) )

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


viewHeading : String -> Maybe String -> Element msg
viewHeading title subLine =
    Element.column
        [ width fill ]
        [ el
            Style.headerStyle
            (text title)
        , case subLine of
            Nothing ->
                none

            Just caption ->
                el Style.captionStyle (text caption)
        , viewDivider
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
            [ viewDeviceSerialInput form.serial form.problems
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

        -- , if model.bus == Nothing then
        --     Dropdown.viewFromModel model busDropdown
        --   else
        --     none
        , viewButton True
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


viewDeviceSerialInput : String -> List (Errors.Errors Problem) -> Element Msg
viewDeviceSerialInput serial problems =
    let
        errorMapper =
            Errors.customInputErrorsFor problems

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
                "serial"
                [ InvalidSerial
                , CameraOpenError
                ]
        , icon = Nothing
        , onChange = ChangedDeviceSerial
        , placeholder = Nothing
        , title = "Device Serial"
        , value = serial
        }


viewDivider =
    el
        [ width (fill |> minimum 20 |> maximum 480)
        , height (px 1)
        , Background.color (rgb255 243 243 243)
        ]
        none


viewButton : Bool -> Element Msg
viewButton enabled =
    StyledElement.button
        (centerX
            :: (if enabled then
                    []

                else
                    [ Background.color (Colors.withAlpha Colors.black 0.5), mouseOver [], pointer ]
               )
        )
        { onPress =
            if enabled then
                Just SubmitButtonMsg

            else
                Nothing
        , label = text "Register"
        }


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


validateForm : Model -> Result (List ( Problem, String )) ValidForm
validateForm { form, bus } =
    let
        problems =
            if Validator.isValidImei form.serial then
                []

            else
                [ ( InvalidSerial, "This value does not have the correct format, please enter it again" ) ]
    in
    case problems of
        [] ->
            Ok
                { serial = form.serial
                , bus_id = bus
                }

        _ ->
            Err problems


submit : Session -> ValidForm -> Cmd Msg
submit session form =
    let
        params =
            Encode.object
                [ ( "bus_id", Encode.int form.bus_id )
                , ( "imei", Encode.string form.serial )
                ]
    in
    Api.post session Endpoint.devices params (Decode.succeed form)
        |> Cmd.map RegisterResponse
