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
import Ports
import RemoteData exposing (..)
import Style exposing (edges)
import Time
import Utils.Date


type alias Model =
    { showGeofence : Bool
    , busID : Int
    }


type Msg
    = AdjustedValue Int


init : Int -> ( Model, Cmd Msg )
init busID =
    ( Model True busID
    , Cmd.batch []
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AdjustedValue sliderValue ->
            ( model, Cmd.none )



-- VIEW


view : Model -> Element msg
view model =
    wrappedRow
        -- [ height (px 10)
        -- , width fill
        -- , Style.clipStyle
        -- , Border.solid
        -- , Border.color (rgb255 197 197 197)
        -- , Border.width 1
        -- , clip
        -- , Background.color (rgba 0 0 0 0.05)
        -- ]
        [ height fill
        , width fill
        , paddingXY 0 10
        ]
        [ viewAddDevice model
        ]


viewAddDevice model =
    Input.button []
        { onPress = Nothing
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
                (column [ padding 8 ]
                    [ Icons.hardware []
                    , el (alignBottom :: Style.header2Style ++ [ Font.color Colors.semiDarkText ]) (text "Add a device")
                    ]
                )
        }
