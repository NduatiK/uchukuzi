port module Models.Location exposing
    ( Location
    , Report
    , clearSchoolLocation
    , locationDecoder
    , reportDecoder
    , storeSchoolLocation
    )

import Iso8601
import Json.Decode as Decode exposing (Decoder, float, string)
import Json.Decode.Pipeline exposing (required, resolve)
import Time


port setSchoolLocation : Maybe Location -> Cmd msg


storeSchoolLocation : Location -> Cmd msg
storeSchoolLocation location =
    setSchoolLocation (Just location)


clearSchoolLocation : Cmd msg
clearSchoolLocation =
    setSchoolLocation Nothing


type alias Location =
    { lng : Float
    , lat : Float
    }


locationDecoder : Decoder Location
locationDecoder =
    Decode.succeed Location
        |> required "lng" float
        |> required "lat" float


type alias Report =
    { location : Location
    , time : Time.Posix
    , speed : Float
    , bearing : Float
    }


reportDecoder : Decoder Report
reportDecoder =
    let
        toDecoder : Location -> String -> Float -> Float -> Decoder Report
        toDecoder location dateString speed bearing =
            case Iso8601.toTime dateString of
                Result.Ok date ->
                    Decode.succeed (Report location date speed bearing)

                Result.Err _ ->
                    Decode.fail (dateString ++ " cannot be decoded to a date")
    in
    Decode.succeed toDecoder
        |> required "location" locationDecoder
        |> required "time" string
        |> required "speed" float
        |> required "bearing" float
        |> resolve
