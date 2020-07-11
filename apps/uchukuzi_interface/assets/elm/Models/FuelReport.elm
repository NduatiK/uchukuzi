module Models.FuelReport exposing
    ( ConsumptionRate
    , Distance
    , FuelReport
    , Volume
    , consumption
    , consumptionToFloat
    , distance
    , distanceDifference
    , distanceToInt
    , fuelRecordDecoder
    , volume
    , volumeSum
    , volumeToFloat
    )

import Iso8601
import Json.Decode as Decode exposing (Decoder, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required, resolve)
import Time


type alias FuelReport =
    { id : Int
    , cost : Int
    , volume : Volume

    -- The total distance covered by the bus since the start of time
    , totalDistanceCovered : Distance
    , tripsMade : Int
    , date : Time.Posix
    }


fuelRecordDecoder : Decoder FuelReport
fuelRecordDecoder =
    let
        decoder id cost volume_ distance_covered dateTimeString tripsMade =
            case Iso8601.toTime dateTimeString of
                Result.Ok dateTime ->
                    Decode.succeed
                        { id = id
                        , cost = cost
                        , volume = Volume volume_
                        , totalDistanceCovered = Distance distance_covered
                        , date = dateTime
                        , tripsMade = tripsMade
                        }

                Result.Err _ ->
                    Decode.fail (dateTimeString ++ " cannot be decoded to a date")
    in
    Decode.succeed decoder
        |> required "id" int
        |> required "cost" int
        |> required "volume" float
        |> required "distance_travelled" int
        |> required "date" string
        |> required "trips_made" int
        |> resolve


type Distance
    = Distance Int


type Volume
    = Volume Float


distance : Int -> Distance
distance =
    Distance


distanceToInt (Distance value) =
    value


volume : Float -> Volume
volume =
    Volume


volumeToFloat (Volume value) =
    value


type ConsumptionRate
    = ConsumptionRate Float


consumption : Distance -> Volume -> ConsumptionRate
consumption (Distance distance1) (Volume volume1) =
    let
        distanceTravelled =
            toFloat distance1 / 1000
    in
    if distanceTravelled > 0 then
        (100 * volume1 / distanceTravelled)
            |> ConsumptionRate

    else
        ConsumptionRate 0


consumptionToFloat (ConsumptionRate value) =
    value |> round100


distanceDifference : Distance -> Distance -> Distance
distanceDifference (Distance distance1) (Distance distance2) =
    Distance (distance1 - distance2)


volumeSum : Volume -> Volume -> Volume
volumeSum (Volume volume1) (Volume volume2) =
    Volume (volume1 + volume2)


round100 : Float -> Float
round100 float =
    toFloat (round (float * 100)) / 100
