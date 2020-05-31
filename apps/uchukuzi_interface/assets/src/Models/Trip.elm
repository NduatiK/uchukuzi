module Models.Trip exposing
    ( LightWeightTrip
    , OngoingTrip
    , StudentActivity
    , Trip
    , ongoingToTrip
    , ongoingTripDecoder
    , tripDecoder
    , tripDetailsDecoder
    )

import Iso8601
import Json.Decode as Decode exposing (Decoder, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required, resolve)
import Models.Location exposing (Location, Report, locationDecoder, reportDecoder)
import Time


type alias LightWeightTrip =
    { id : Int
    , startTime : Time.Posix
    , endTime : Time.Posix
    , travelTime : String
    , studentActivities : List StudentActivity
    , distanceCovered : Float
    }


type alias OngoingTrip =
    { startTime : Time.Posix
    , reports : List Report
    , studentActivities : List StudentActivity
    }


ongoingToTrip ongoing =
    { id = 1
    , startTime = ongoing.startTime
    , endTime =
        ongoing.reports
            |> List.head
            |> Maybe.andThen (.time >> Just)
            |> Maybe.withDefault ongoing.startTime
    , travelTime = ""
    , reports = List.reverse <| ongoing.reports
    , studentActivities = ongoing.studentActivities
    , distanceCovered = 0
    }


type alias Trip =
    { id : Int
    , startTime : Time.Posix
    , endTime : Time.Posix
    , travelTime : String
    , reports : List Report
    , studentActivities : List StudentActivity
    , distanceCovered : Float
    }


type alias StudentActivity =
    { location : Location
    , time : Time.Posix
    , activity : String
    , student : Int
    , studentName : String
    }


tripDecoder : Decoder LightWeightTrip
tripDecoder =
    let
        toDecoder : Int -> String -> String -> String -> Float -> List StudentActivity -> Decoder LightWeightTrip
        toDecoder id startDateString endDateString travelTime distanceCovered studentActivities =
            case ( Iso8601.toTime startDateString, Iso8601.toTime endDateString ) of
                ( Result.Ok startDate, Result.Ok endDate ) ->
                    Decode.succeed
                        { id = id
                        , startTime = startDate
                        , endTime = endDate
                        , travelTime = travelTime
                        , distanceCovered = distanceCovered
                        , studentActivities = studentActivities
                        }

                ( Result.Err _, _ ) ->
                    Decode.fail (startDateString ++ " cannot be decoded to a date")

                ( _, Result.Err _ ) ->
                    Decode.fail (endDateString ++ " cannot be decoded to a date")
    in
    Decode.succeed toDecoder
        |> required "id" int
        |> required "start_time" string
        |> required "end_time" string
        |> required "travel_time" string
        |> required "distance_covered" float
        |> required "student_activities" (list activityDecoder)
        |> resolve


tripDetailsDecoder : Decoder Trip
tripDetailsDecoder =
    let
        toDecoder : Int -> String -> String -> String -> List Report -> Float -> List StudentActivity -> Decoder Trip
        toDecoder id startDateString endDateString travelTime reports distanceCovered studentActivities =
            case ( Iso8601.toTime startDateString, Iso8601.toTime endDateString ) of
                ( Result.Ok startDate, Result.Ok endDate ) ->
                    Decode.succeed
                        { id = id
                        , startTime = startDate
                        , endTime = endDate
                        , travelTime = travelTime
                        , reports = reports
                        , distanceCovered = distanceCovered
                        , studentActivities = studentActivities
                        }

                ( Result.Err _, _ ) ->
                    Decode.fail (startDateString ++ " cannot be decoded to a date")

                ( _, Result.Err _ ) ->
                    Decode.fail (endDateString ++ " cannot be decoded to a date")
    in
    Decode.succeed toDecoder
        |> required "id" int
        |> required "start_time" string
        |> required "end_time" string
        |> required "travel_time" string
        |> required "reports" (list reportDecoder)
        |> required "distance_covered" float
        |> required "student_activities" (list activityDecoder)
        |> resolve


ongoingTripDecoder : Decoder OngoingTrip
ongoingTripDecoder =
    let
        toDecoder : String -> List Report -> List StudentActivity -> Decoder OngoingTrip
        toDecoder startDateString reports studentActivities =
            case Iso8601.toTime startDateString of
                Result.Ok startDate ->
                    Decode.succeed
                        { startTime = startDate
                        , reports = reports
                        , studentActivities = studentActivities
                        }

                Result.Err _ ->
                    Decode.fail (startDateString ++ " cannot be decoded to a date")
    in
    Decode.succeed toDecoder
        |> required "start_time" string
        |> required "reports" (list reportDecoder)
        |> required "student_activities" (list activityDecoder)
        |> resolve



-- { id : Int
--         , reports : List Report
--         , startTime : Time.Posix
--         , studentActivities : List StudentActivity
--         }


activityDecoder : Decoder StudentActivity
activityDecoder =
    let
        toDecoder : Location -> String -> String -> Int -> String -> Decoder StudentActivity
        toDecoder location dateString activity student studentName =
            case Iso8601.toTime dateString of
                Result.Ok date ->
                    Decode.succeed (StudentActivity location date activity student studentName)

                Result.Err _ ->
                    Decode.fail (dateString ++ " cannot be decoded to a date")
    in
    Decode.succeed toDecoder
        |> required "location" locationDecoder
        |> required "time" string
        |> required "activity" string
        |> required "student" int
        |> optional "student_name" string ""
        |> resolve
