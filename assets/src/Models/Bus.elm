module Models.Bus exposing
    ( Bus
    , Device
    , LocationUpdate
    , Part(..)
    , RepairRecord
    , Route
    , VehicleType(..)
    , busDecoder
    , busDecoderWithCallback
    , imageForPart
    , titleForPart
    , vehicleTypeToString
    )

import Element
import Icons.Repairs
import Json.Decode as Decode exposing (Decoder, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required, resolve)
import Models.Location exposing (Location, locationDecoder)


type alias Bus =
    { id : Int
    , numberPlate : String
    , seats_available : Int
    , vehicleType : VehicleType
    , stated_milage : Float
    , route : Maybe Route
    , device : Maybe Device
    , repairs : List RepairRecord
    , last_seen : Maybe LocationUpdate
    }


type alias Route =
    { id : String
    , name : String
    }


type alias Device =
    String


type alias LocationUpdate =
    { bus : Int
    , location : Location
    , speed : Float
    , bearing : Float
    }



-- type alias Student =
--     { id : String
--     , name : String
--     }


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


type alias RepairRecord =
    { id : Int
    , part : Part
    , description : String
    , cost : Int
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
        busDataDecoder id number_plate seats_available vehicle_type stated_milage route device repairs update =
            let
                bus =
                    let
                        lastSeen =
                            Maybe.andThen
                                (\update_ ->
                                    Just (LocationUpdate id update_.location update_.speed update_.bearing)
                                )
                                update

                        vehicleType =
                            case vehicle_type of
                                "van" ->
                                    Van

                                "shuttle" ->
                                    Shuttle

                                _ ->
                                    SchoolBus
                    in
                    Bus id number_plate seats_available vehicleType stated_milage route device repairs lastSeen
            in
            Decode.succeed (callback bus)
    in
    Decode.succeed busDataDecoder
        |> required "id" int
        |> required "number_plate" string
        |> required "seats_available" int
        |> required "vehicle_type" string
        |> required "stated_milage" float
        |> required "route" (nullable routeDecoder)
        |> required "device" (nullable string)
        |> required "performed_repairs" (list repairDecoder)
        |> required "last_seen" (nullable locationUpdateDecoder)
        |> resolve


busDecoder : Decoder Bus
busDecoder =
    busDecoderWithCallback identity


routeDecoder : Decoder Route
routeDecoder =
    Decode.succeed Route
        |> required "id" string
        |> required "name" string


repairDecoder : Decoder RepairRecord
repairDecoder =
    let
        decoder id part description cost =
            Decode.succeed (RepairRecord id (toPart part) description cost)
    in
    Decode.succeed decoder
        |> required "id" int
        |> required "part" string
        |> required "description" string
        |> required "cost" int
        |> resolve


locationUpdateDecoder : Decoder LocationUpdate
locationUpdateDecoder =
    Decode.succeed LocationUpdate
        |> Json.Decode.Pipeline.hardcoded 0
        |> required "location" locationDecoder
        |> required "speed" float
        |> required "bearing" float
