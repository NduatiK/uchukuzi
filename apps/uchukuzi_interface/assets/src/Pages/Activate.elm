module Pages.Activate exposing (Model, Msg, init, update, view)

import Api exposing (SuccessfulLogin)
import Api.Endpoint
import Element exposing (..)
import Icons
import Json.Encode as Encode
import Models.Location
import Navigation
import RemoteData exposing (..)
import Session exposing (Session)


type alias Model =
    { session : Session
    , requestState : WebData SuccessfulLogin
    , token : String
    }


init : Session -> String -> ( Model, Cmd Msg )
init session token =
    ( Model session Loading token, activateAccount session token )


type Msg
    = ReceivedActivationResponse (WebData SuccessfulLogin)
    | RequestActivate


view : Model -> Element msg
view model =
    el [ width fill, height fill ] (Icons.loading [ centerX, centerY ])


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceivedActivationResponse response ->
            let
                newModel =
                    { model | requestState = response }
            in
            case response of
                Success data ->
                    ( newModel
                    , Cmd.batch
                        [ Api.storeCredentials data.creds
                        , Models.Location.storeSchoolLocation data.location
                        , Navigation.rerouteTo model Navigation.Buses
                        ]
                    )

                _ ->
                    ( newModel, Cmd.none )

        RequestActivate ->
            ( model, activateAccount model.session model.token )


activateAccount session token =
    let
        params =
            Encode.object
                [ ( "token", Encode.string token )
                ]
    in
    Api.post session Api.Endpoint.activate params Api.loginDecoder
        |> Cmd.map ReceivedActivationResponse
