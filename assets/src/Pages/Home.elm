module Pages.Home exposing (Model, init, view)

import Element exposing (..)
import Html exposing (Html)
import Html.Events exposing (..)
import Icons
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
