module Models.Bus exposing
    ( Bus
    , Device
    , LocationUpdate
    , Part(..)
    , Repair
    , SimpleRoute
    , VehicleType(..)
    , busDecoder
    , busDecoderWithCallback
    , defaultSeats
    , imageForPart
    , locationUpdateDecoder
    , simpleRouteDecoder
    , titleForPart
    , vehicleTypeToIcon
    , vehicleTypeToString
    )

import Element
import Icons
import Icons.Repairs
import Iso8601
import Json.Decode as Decode exposing (Decoder, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, optionalAt, required, resolve)
import Models.Location exposing (Location, locationDecoder)
import Time


type alias Bus =
    { id : Int
    , numberPlate : String
    , occupiedSeats : Int
    , seatsAvailable : Int
    , vehicleType : VehicleType
    , route : Maybe SimpleRoute
    , device : Maybe Device
    , repairs : List Repair
    , lastSeen : Maybe LocationUpdate
    }


type alias SimpleRoute =
    { id : Int
    , name : String
    , busID : Maybe Int
    }


type alias Device =
    String


type alias LocationUpdate =
    { bus : Int
    , location : Location
    , speed : Float
    , bearing : Float
    }


type VehicleType
    = Van
    | Shuttle
    | SchoolBus


vehicleTypeToString : VehicleType -> String
vehicleTypeToString vehicleType =
    case vehicleType of
        Van ->
            "van"

        Shuttle ->
            "shuttle"

        SchoolBus ->
            "bus"


type alias Repair =
    { id : Int
    , part : Part
    , description : String
    , cost : Int
    , dateTime : Time.Posix
    }


type Part
    = FrontLeftTire
    | FrontRightTire
    | RearLeftTire
    | RearRightTire
    | Engine
    | FrontCrossAxis
    | RearCrossAxis
    | VerticalAxis


imageForPart : Part -> List (Element.Attribute msg) -> Element.Element msg
imageForPart part =
    case part of
        VerticalAxis ->
            Icons.Repairs.verticalAxisRepair

        Engine ->
            Icons.Repairs.engineRepair

        FrontLeftTire ->
            Icons.Repairs.frontLeftTireRepair

        FrontRightTire ->
            Icons.Repairs.frontRightTireRepair

        RearLeftTire ->
            Icons.Repairs.rearLeftTireRepair

        RearRightTire ->
            Icons.Repairs.rearRightTireRepair

        FrontCrossAxis ->
            Icons.Repairs.frontCrossAxisRepair

        RearCrossAxis ->
            Icons.Repairs.rearCrossAxisRepair


toPart : String -> Part
toPart partString =
    case partString of
        "Front Left Tire" ->
            FrontLeftTire

        "Front Right Tire" ->
            FrontRightTire

        "Rear Left Tire" ->
            RearLeftTire

        "Rear Right Tire" ->
            RearRightTire

        "Front Cross Axis" ->
            FrontCrossAxis

        "Rear Cross Axis" ->
            RearCrossAxis

        "Vertical Axis" ->
            VerticalAxis

        _ ->
            Engine


titleForPart : Part -> String
titleForPart part =
    case part of
        FrontLeftTire ->
            "Front Left Tire"

        FrontRightTire ->
            "Front Right Tire"

        RearLeftTire ->
            "Rear Left Tire"

        RearRightTire ->
            "Rear Right Tire"

        Engine ->
            "Engine"

        FrontCrossAxis ->
            "Front Cross Axis"

        RearCrossAxis ->
            "Rear Cross Axis"

        VerticalAxis ->
            "Vertical Axis"


busDecoderWithCallback : (Bus -> a) -> Decoder a
busDecoderWithCallback callback =
    let
        busDataDecoder id numberPlate occupiedSeats seatsAvailable vehicleType route device repairs update =
            let
                lastSeen =
                    Maybe.map (\x -> { x | bus = id }) update
            in
            Decode.succeed
                (callback
                    { id = id
                    , numberPlate = numberPlate
                    , occupiedSeats = occupiedSeats
                    , seatsAvailable = seatsAvailable
                    , vehicleType = vehicleType
                    , route = route
                    , device = device
                    , repairs = repairs
                    , lastSeen = lastSeen
                    }
                )
    in
    Decode.succeed busDataDecoder
        |> required "id" int
        |> required "number_plate" string
        |> required "occupied_seats" int
        |> required "seats_available" int
        |> required "vehicle_type" vehicleTypeDecoder
        |> required "route" (nullable simpleRouteDecoder)
        |> required "device" (nullable string)
        |> required "performed_repairs" (list repairDecoder)
        |> required "last_seen" (nullable locationUpdateDecoder)
        |> resolve


busDecoder : Decoder Bus
busDecoder =
    busDecoderWithCallback identity


simpleRouteDecoder : Decoder SimpleRoute
simpleRouteDecoder =
    Decode.succeed SimpleRoute
        |> required "id" int
        |> required "name" string
        |> optionalAt [ "bus", "id" ] (nullable int) Nothing


repairDecoder : Decoder Repair
repairDecoder =
    let
        decoder id part description cost dateTimeString =
            case Iso8601.toTime dateTimeString of
                Result.Ok dateTime ->
                    Decode.succeed
                        { id = id
                        , part = toPart part
                        , description = description
                        , cost = cost
                        , dateTime = dateTime
                        }

                Result.Err _ ->
                    Decode.fail (dateTimeString ++ " cannot be decoded to a date")
    in
    Decode.succeed decoder
        |> required "id" int
        |> required "part" string
        |> required "description" string
        |> required "cost" int
        |> required "time" string
        |> resolve


locationUpdateDecoder : Decoder LocationUpdate
locationUpdateDecoder =
    Decode.succeed LocationUpdate
        |> required "bus" int
        |> required "location" locationDecoder
        |> required "speed" float
        |> required "bearing" float


vehicleTypeDecoder : Decoder VehicleType
vehicleTypeDecoder =
    string
        |> Decode.map
            (\x ->
                case x of
                    "van" ->
                        Van

                    "shuttle" ->
                        Shuttle

                    _ ->
                        SchoolBus
            )


vehicleTypeToIcon : VehicleType -> Icons.IconBuilder msg
vehicleTypeToIcon vehicleType =
    case vehicleType of
        Van ->
            Icons.van

        Shuttle ->
            Icons.shuttle

        SchoolBus ->
            Icons.bus


defaultSeats : VehicleType -> Int
defaultSeats vehicle =
    case vehicle of
        Van ->
            12

        Shuttle ->
            24

        SchoolBus ->
            48
