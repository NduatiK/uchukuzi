module Models.School exposing
    ( School
    , schoolDecoder
    )

import Json.Decode as Decode exposing (Decoder, string)
import Json.Decode.Pipeline exposing (required)
import Models.Location as Location


type alias School =
    { location : Location.Location
    , radius : Float
    , name : String
    , deviationRadius : Int
    }


schoolDecoder : Decoder School
schoolDecoder =
    Decode.succeed School
        |> required "location" Location.locationDecoder
        |> required "radius" Decode.float
        |> required "name" string
        |> required "deviation_radius" Decode.int
