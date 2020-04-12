module Pages.Home exposing (Model, init, view)

import Browser
import Dropdown
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Html exposing (Html)
import Html.Events exposing (..)
import Icons
import Json.Decode as Decode
import Navigation exposing (href)
import Session exposing (Session)
import Style exposing (edges)
import Views.Heading exposing (viewHeading)


type alias Model =
    { session : Session }


init : Session -> ( Model, Cmd msg )
init session =
    ( Model session
    , Cmd.none
    )



-- UPDATE


update : msg -> model -> ( model, Cmd msg )
update msg model =
    ( model, Cmd.none )



-- VIEW


view : Element msg
view =
    Element.column
        [ width fill, spacing 40, paddingXY 24 8 ]
        [ viewHeading "Home" Nothing
        , el [] (text "Welcome")
        ]
