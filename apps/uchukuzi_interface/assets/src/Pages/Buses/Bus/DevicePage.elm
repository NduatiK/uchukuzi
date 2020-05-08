module Pages.Buses.Bus.DevicePage exposing (Model, Msg, init, update, view, viewFooter)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Icons
import Models.Bus exposing (Bus)
import Navigation
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import StyledElement.Footer as Footer


type alias Model =
    { currentPage : Page
    , session : Session
    , bus : Bus
    }


type Page
    = About
    | Features


pageToString : Page -> String
pageToString page =
    case page of
        About ->
            "About"

        Features ->
            "Features"


type Msg
    = AddDevice
    | RemoveDevice
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
            ( { model | currentPage = About }, Cmd.none )

        ClickedFeaturesPage ->
            ( { model | currentPage = Features }, Cmd.none )

        RemoveDevice ->
            ( model, Cmd.none )



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


viewDeviceRegistration : Model -> Element Msg
viewDeviceRegistration model =
    column
        [ spacing 60
        , centerX
        ]
        [ column [ spacing 30, centerX ]
            [ Icons.dashedBox [ Background.color Colors.white ]
            , el (centerX :: Style.labelStyle) (text "You have not yet linked a device to this bus")
            ]
        , StyledElement.button
            [ Background.color Colors.purple, alignBottom, centerX ]
            { label =
                row [ spacing 8 ]
                    [ Icons.add [ centerY, Colors.fillWhite, alpha 1 ]
                    , el [ centerY, paddingEach { edges | top = 2 } ] (text "Add device")
                    ]
            , onPress = Just AddDevice
            }
        ]


viewDevice : Models.Bus.Device -> Element Msg
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

                -- , StyledElement.textStack "Added On" "1231 4453 7523 1262"
                ]
            ]
        , el [] none
        , el [ alignRight, alignBottom ]
            (StyledElement.button
                [ Background.color Colors.errorRed, alignBottom, alignRight ]
                { label =
                    row [ spacing 8 ]
                        [ Icons.trash [ centerY, Colors.fillWhite, alpha 1 ], el [ centerY, paddingEach { edges | top = 2 } ] (text "Remove from bus") ]
                , onPress = Just RemoveDevice
                }
            )
        ]


viewDeviceFeatures : Models.Bus.Device -> Element Msg
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
                , onPress = Just RemoveDevice
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


viewAddDevice : Model -> Element Msg
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
                    ]
                    [ Icons.hardware []
                    , el (alignBottom :: Style.header2Style ++ [ Font.color Colors.semiDarkText ])
                        (text "Add a device")
                    ]
                )
        }
