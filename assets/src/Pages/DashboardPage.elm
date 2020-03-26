module Pages.DashboardPage exposing (Model, Msg, init, update, view)

-- , view

import Api
import Api.Endpoint as Endpoint
import Element exposing (..)
import Json.Decode as Decode exposing (Decoder, float, list, string)
import Json.Decode.Pipeline exposing (optional, required)
import RemoteData exposing (..)
import Session exposing (Session)


type alias Model =
    { session : Session
    , buses : WebData (List Bus)
    }


type alias Bus =
    { numberPlate : String
    , route : String
    , location : Location
    }


type alias Location =
    { longitude : Float
    , latitude : Float
    }


type Msg
    = ClickedBus Bus
    | BusesResponse (WebData (List Bus))


init : Session -> ( Model, Cmd msg )
init session =
    ( Model session RemoteData.Loading, Cmd.none )



-- UPDATE


update msg model =
    case msg of
        ClickedBus bus ->
            ( model, Cmd.none )

        BusesResponse response ->
            case response of
                Loading ->
                    ( model, Cmd.none )

                NotAsked ->
                    ( model, Cmd.none )

                Failure _ ->
                    ( model, Cmd.none ) 

                Success _ ->
                    ( model, Cmd.none )



-- VIEW


view : Model -> Element Msg
view model =
    row [] []



-- HTTP


fetchTripsForBus : Session -> String -> Cmd Msg
fetchTripsForBus session bus =
    let
        params =
            { bus_id = bus }
    in
    Api.get session Endpoint.buses (list busDecoder)
        |> Cmd.map BusesResponse


busDecoder : Decoder Bus
busDecoder =
    Decode.succeed Bus
        |> required "numberPlate" string
        |> required "route" string
        |> required "location" locationDecoder


locationDecoder : Decoder Location
locationDecoder =
    Decode.succeed Location
        |> required "longitude" float
        |> required "latitude" float
