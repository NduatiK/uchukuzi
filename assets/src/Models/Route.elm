module Models.Route exposing (Route, routeDecoder)

import Json.Decode as Decode exposing (Decoder, list, string)
import Json.Decode.Pipeline exposing (required)
import Models.Location exposing (Location, locationDecoder)


type alias Route =
    { id : String
    , name : String
    , point : List Location
    }


routeDecoder : Decoder Route
routeDecoder =
    Decode.succeed Route
        |> required "id" string
        |> required "name" string
        |> required "stops" (list locationDecoder)
