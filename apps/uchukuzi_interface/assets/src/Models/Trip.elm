module Models.Trip exposing
    ( LightWeightTrip
    , OngoingTrip
    , StudentActivity
    , Trip
    , annotatedReports
    , ongoingToTrip
    , ongoingTripDecoder
    , pointAt
    , studentActivityDecoder
    , tripDecoder
    , tripDetailsDecoder
    )

import Iso8601
import Json.Decode as Decode exposing (Decoder, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required, resolve)
import Models.Location exposing (Location, Report, locationDecoder, reportDecoder)
import Models.Tile as Tile
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
    , crossedTiles : List Location
    , deviations : List Int
    }


ongoingToTrip ongoing =
    { id = 1
    , startTime = ongoing.startTime
    , endTime =
        ongoing.reports
            |> List.head
            |> Maybe.map .time
            |> Maybe.withDefault ongoing.startTime
    , travelTime = ""
    , reports = List.reverse <| ongoing.reports
    , studentActivities = ongoing.studentActivities
    , distanceCovered = 0
    , crossedTiles = ongoing.crossedTiles
    , deviations = ongoing.deviations
    }


type alias Trip =
    { id : Int
    , startTime : Time.Posix
    , endTime : Time.Posix
    , travelTime : String
    , reports : List Report
    , studentActivities : List StudentActivity
    , distanceCovered : Float
    , crossedTiles : List Location
    , deviations : List Int
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
        |> required "student_activities" (list studentActivityDecoder)
        |> resolve


tripDetailsDecoder : Decoder Trip
tripDetailsDecoder =
    let
        toDecoder : Int -> String -> String -> String -> List Report -> Float -> List StudentActivity -> List Location -> List Int -> Decoder Trip
        toDecoder id startDateString endDateString travelTime reports distanceCovered studentActivities crossedTiles deviations =
            case ( Iso8601.toTime startDateString, Iso8601.toTime endDateString ) of
                ( Result.Ok startDate, Result.Ok endDate ) ->
                    Decode.succeed
                        { id = id
                        , startTime = startDate
                        , endTime = endDate
                        , travelTime = travelTime
                        , reports = List.reverse <| reports
                        , distanceCovered = distanceCovered
                        , studentActivities = studentActivities
                        , crossedTiles = crossedTiles
                        , deviations = deviations
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
        |> required "student_activities" (list studentActivityDecoder)
        |> required "crossed_tiles" (list locationDecoder)
        |> required "deviations" (list int)
        |> resolve


ongoingTripDecoder : Decoder OngoingTrip
ongoingTripDecoder =
    let
        toDecoder : String -> List Report -> List StudentActivity -> List Location -> List Int -> Decoder OngoingTrip
        toDecoder startDateString reports studentActivities crossedTiles deviations =
            case Iso8601.toTime startDateString of
                Result.Ok startDate ->
                    Decode.succeed
                        { startTime = startDate
                        , reports = reports
                        , studentActivities = studentActivities
                        , crossedTiles = crossedTiles
                        , deviations = deviations
                        }

                Result.Err _ ->
                    Decode.fail (startDateString ++ " cannot be decoded to a date")
    in
    Decode.succeed toDecoder
        |> required "start_time" string
        |> required "reports" (list reportDecoder)
        |> required "student_activities" (list studentActivityDecoder)
        |> required "crossed_tiles" (list locationDecoder)
        |> required "deviations" (list int)
        |> resolve


studentActivityDecoder : Decoder StudentActivity
studentActivityDecoder =
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


pointAt : Int -> Trip -> Maybe Report
pointAt index trip =
    List.head (List.drop index trip.reports)


annotatedReports : Trip -> List { report : Report, deviated : Bool }
annotatedReports trip =
    let
        indexedTiles_ =
            trip.crossedTiles
                |> List.map Tile.newTile
                |> List.indexedMap Tuple.pair

        emptyList : List { report : Report, deviated : Bool }
        emptyList =
            []
    in
    trip.reports
        |> List.foldl
            (\report ( indexedTiles, annotatedReports_ ) ->
                case List.head indexedTiles of
                    Just ( index, tile ) ->
                        if Tile.contains report.location tile then
                            ( indexedTiles
                            , { report = report, deviated = List.member index trip.deviations }
                                :: annotatedReports_
                            )

                        else
                            let
                                tail =
                                    List.drop 1 indexedTiles
                            in
                            case List.head tail of
                                Just ( idx, headOfTail ) ->
                                    if Tile.contains report.location headOfTail then
                                        ( tail
                                        , { report = report, deviated = List.member idx trip.deviations }
                                            :: annotatedReports_
                                        )

                                    else
                                        ( tail
                                        , { report = report, deviated = False }
                                            :: annotatedReports_
                                        )

                                Nothing ->
                                    ( tail
                                    , { report = report, deviated = False }
                                        :: annotatedReports_
                                    )

                    Nothing ->
                        ( []
                        , { report = report, deviated = False }
                            :: annotatedReports_
                        )
            )
            ( indexedTiles_, emptyList )
        |> Tuple.second
        |> List.reverse
