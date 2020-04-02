module Pages.Buses.AboutBus exposing (Model, Msg, init, update, view)

import Api exposing (get)
import Api.Endpoint as Endpoint exposing (trips)
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Html.Attributes exposing (class, id)
import Icons
import Iso8601
import Json.Decode as Decode exposing (Decoder, float, int, list, string)
import Json.Decode.Pipeline exposing (optional, required, resolve)
import Models.Bus exposing (Bus)
import Ports
import RemoteData exposing (..)
import Route
import Session exposing (Session)
import Style exposing (edges)
import Time
import Utils.Date


type alias Model =
    { showGeofence : Bool
    , bus : Bus
    , session : Session
    }


type Msg
    = AddDevice


init : Session -> Bus -> ( Model, Cmd Msg )
init session bus =
    ( Model True bus session
    , Cmd.batch []
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AddDevice ->
            ( model, Route.rerouteTo model (Route.BusDeviceRegistration model.bus.id) )



-- VIEW


view : Model -> ( Element Msg, Element Msg )
view model =
    ( viewBody model, viewBody model )


viewBody model =
    wrappedRow
        [ height fill
        , width fill
        , paddingXY 0 10
        , Background.color Colors.black
        ]
        [ if model.bus.device == Nothing then
            viewAddDevice model

          else
            none
        ]


viewAddDevice model =
    Input.button []
        { onPress = Just AddDevice
        , label =
            el
                [ height (px 100)
                , Border.color Colors.purple
                , alignTop
                , width (px 200)
                , Style.elevated
                , Style.animatesAll
                , mouseOver [ Style.elevated2 ]
                , Border.rounded 3
                , Border.width 1
                ]
                (column
                    [ padding 8
                    , width fill
                    , height fill

                    -- , Border.width 1
                    -- , Border.color Colors.white
                    -- -- , Background.color Colors.purple
                    ]
                    [ Icons.hardware []
                    , el (alignBottom :: Style.header2Style ++ [ Font.color Colors.semiDarkText ])
                        (text "Add a device")
                    ]
                )
        }
