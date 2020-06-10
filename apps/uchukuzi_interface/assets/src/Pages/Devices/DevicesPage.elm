module Pages.Devices.DevicesPage exposing (Model, Msg, init, update, view)

import Api
import Api.Endpoint as Endpoint
import Element exposing (..)
import Errors
import Icons
import Json.Decode exposing (Decoder, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required)
import Navigation exposing (Route)
import RemoteData exposing (..)
import Session exposing (Session)
import Style
import StyledElement
import StyledElement.WebDataView as WebDataView


type alias Model =
    { session : Session
    , devices : WebData (List Device)
    }


type alias Device =
    { imei : String
    , bus : Maybe Bus
    }


type alias Bus =
    { id : Int
    , numberPlate : String
    }


type Msg
    = ReceivedDevicesResponse (WebData (List Device))


init : Session -> ( Model, Cmd Msg )
init session =
    ( Model session RemoteData.Loading, fetchDevices session )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceivedDevicesResponse devices ->
            ( { model | devices = devices }
            , Cmd.none
            )



-- VIEW


view : Model -> Element msg
view model =
    column [ width fill, spacing 40, paddingXY 24 8 ]
        [ viewHeading "*Devices****" (Just "Place this within the bus")

        -- , Element.column []
        -- [ StyledElement.buttonLink []
        --     { route = Navigation.DeviceRegistration
        --     , label = text "Add a device"
        --     }
        -- , viewBody model
        -- ]
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
        ]


viewBody : Model -> Element msg
viewBody model =
    WebDataView.view model.devices
        (\devices ->
            viewDevicesTable devices
        )


viewDevicesTable devices =
    let
        rowTextStyle =
            width (fill |> minimum 220) :: Style.tableElementStyle

        tableHeader text =
            el Style.tableHeaderStyle (Element.text (String.toUpper text))
    in
    Element.table
        [ spacing 20 ]
        { data = devices
        , columns =
            [ { header = tableHeader "IMEI"
              , width = shrink
              , view =
                    \device ->
                        el
                            rowTextStyle
                            (Element.text device.imei)
              }
            , { header = tableHeader "BUS"
              , width = shrink
              , view =
                    \device ->
                        case device.bus of
                            Just bus ->
                                StyledElement.textLink []
                                    { label = text bus.numberPlate
                                    , route = Navigation.Bus bus.id (Just "Device")
                                    }

                            Nothing ->
                                none
              }
            ]
        }


fetchDevices : Session -> Cmd Msg
fetchDevices session =
    Api.get session Endpoint.devices (list deviceDecoder)
        |> Cmd.map ReceivedCreateResponse


deviceDecoder : Decoder Device
deviceDecoder =
    Json.Decode.succeed Device
        |> required "imei" string
        |> required "bus" (nullable busDecoder)


busDecoder : Decoder Bus
busDecoder =
    Json.Decode.succeed Bus
        |> required "id" int
        |> required "number_plate" string
