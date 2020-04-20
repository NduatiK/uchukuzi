module Pages.Logout exposing (Model, init, view)

import Api
import Element exposing (Element, el, none)
import Session exposing (Session)


type alias Model =
    { session : Session }


init : Session -> ( Model, Cmd msg )
init session =
    ( Model session
    , Api.logout
    )


view : Element msg
view =
    el [] none
