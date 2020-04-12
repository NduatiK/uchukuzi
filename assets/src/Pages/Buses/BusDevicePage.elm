module Pages.Buses.BusDevicePage exposing (Model, Msg, init, update, view, viewFooter)

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
import Navigation
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import StyledElement.Footer as Footer
import Time
import Utils.Date


type alias Model =
    { currentPage : Page
    , session : Session
    , bus : Bus
    }


type Page
    = About
    | Features


pageToString page =
    case page of
        About ->
            "About"

        Features ->
            "Features"


type Msg
    = AddDevice
      ------
    | ClickedAboutPage
    | ClickedFeaturesPage


init : Bus -> Session -> ( Model, Cmd Msg )
init bus session =
    ( Model About session bus
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AddDevice ->
            ( model, Navigation.rerouteTo model (Navigation.BusDeviceRegistration model.bus.id) )

        ClickedAboutPage ->
            ( { model | currentPage = About }, Ports.initializeMaps False )

        ClickedFeaturesPage ->
            ( { model | currentPage = Features }, Cmd.none )



-- VIEW


view : Model -> Element Msg
view model =
    case model.bus.device of
        Just device ->
            case model.currentPage of
                About ->
                    viewDevice device

                Features ->
                    viewDeviceFeatures device

        Nothing ->
            viewDeviceRegistration model


viewDeviceRegistration model =
    column
        [ spacing 80
        ]
        [ Icons.dashedBox [ Background.color Colors.white ]
        , el [] none
        ]


viewDevice device =
    let
        take4 : List String -> String -> List String
        take4 list string =
            if string == "" then
                list

            else
                take4 (String.left 4 string :: list) (String.dropLeft 4 string)

        formattedSerial =
            String.join " " (List.reverse (take4 [] device))
    in
    column [ width fill, height fill ]
        [ row
            [ spacing 80, centerX, width fill, height fill, paddingXY 80 0 ]
            [ Icons.box [ Background.color Colors.white, alpha 1 ]
            , column
                [ centerY, spacing 40, width fill, paddingEach { edges | bottom = 20 } ]
                [ StyledElement.textStack "Serial No" formattedSerial
                , StyledElement.textStack "Serial No" "1231 4453 7523 1262"
                ]
            ]
        , el [] none
        , el [ alignRight, alignBottom ]
            (StyledElement.button
                [ Background.color Colors.errorRed, alignBottom, alignRight ]
                { label =
                    row [ spacing 8 ]
                        [ Icons.trash [ centerY, Colors.fillWhite, alpha 1 ], el [ centerY, paddingEach { edges | top = 2 } ] (text "Remove from bus") ]
                , onPress = Just AddDevice
                }
            )
        ]


viewDeviceFeatures device =
    column [ width fill, height fill ]
        [ row
            [ spacing 80, centerX, width fill, height fill, paddingXY 80 0 ]
            [ Icons.box [ Background.color Colors.white, alpha 1 ]
            , column
                [ centerY, spacing 40, width fill, paddingEach { edges | bottom = 20 } ]
                [ StyledElement.textStack "Tracking " "Location tracking with\n5 metre resolution"
                , StyledElement.textStack "Realtime Reporting" "Know where your bus is\nright now"
                , StyledElement.textStack "Battery Optimization" "Last longer between charges"
                ]
            ]
        , el [] none
        , el [ alignRight, alignBottom ]
            (StyledElement.button
                [ Background.color Colors.errorRed, alignBottom, alignRight ]
                { label =
                    row [ spacing 8 ]
                        [ Icons.trash [ centerY, Colors.fillWhite, alpha 1 ], el [ centerY, paddingEach { edges | top = 2 } ] (text "Remove from bus") ]
                , onPress = Just AddDevice
                }
            )
        ]


viewFooter : Model -> Element Msg
viewFooter model =
    case model.bus.device of
        Just device ->
            column [ width fill ]
                [ Footer.view model.currentPage
                    pageToString
                    [ ( About, "", ClickedAboutPage )
                    , ( Features, "", ClickedFeaturesPage )
                    ]
                , el [ height (px 24) ] none
                ]

        Nothing ->
            none


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
