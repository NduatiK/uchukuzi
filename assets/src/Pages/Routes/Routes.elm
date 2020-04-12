module Pages.Routes.Routes exposing (Model, Msg, init, update, view)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Icons
import Models.Route exposing (Route)
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style
import StyledElement


type alias Model =
    { session : Session
    , routes : WebData (List Route)
    , filterText : String
    }


type Msg
    = Add


init : Session -> ( Model, Cmd Msg )
init session =
    ( Model session NotAsked ""
    , Cmd.batch
        [ Ports.initializeMaps False
        ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Add ->
            ( model, Cmd.none )


view : Model -> Element Msg
view model =
    column [ paddingXY 90 60, width fill, spacing 16 ]
        [ googleMap
        , viewHeading "All Routes" Nothing
        ]


viewHeading : String -> Maybe String -> Element Msg
viewHeading title subLine =
    row [ spacing 16, width fill ]
        [ Element.column
            [ width fill ]
            [ el
                Style.headerStyle
                (text title)
            , case subLine of
                Nothing ->
                    none

                Just caption ->
                    el Style.captionLabelStyle (text caption)
            ]
        , StyledElement.textInput
            [ alignRight, width (fill |> maximum 300), centerY ]
            { title = ""
            , caption = Nothing
            , errorCaption = Nothing
            , value = ""
            , onChange = always Add
            , placeholder = Just (Input.placeholder [] (text "Search"))
            , ariaLabel = "Filter buses"
            , icon = Just Icons.search
            }
        , StyledElement.iconButton
            [ centerY
            , alignRight
            ]
            { icon = Icons.addWhite
            , iconAttrs = []
            , onPress = Nothing
            }
        ]


googleMap : Element Msg
googleMap =
    column
        [ width fill
        , height fill
        ]
        [ StyledElement.googleMap
            [ width fill
            , height (fill |> minimum 500)
            ]
        , el [ height (px 2), width fill, Background.color Colors.darkness ] none
        ]
