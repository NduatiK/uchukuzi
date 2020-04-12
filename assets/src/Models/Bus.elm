module Models.Bus exposing
    ( Bus
    , Device
    , LocationUpdate
    , Route
    , VehicleType(..)
    , busDecoder
    , busDecoderWithCallback
    , vehicleTypeToString
    )

import Json.Decode as Decode exposing (Decoder, float, int, nullable, string)
import Json.Decode.Pipeline exposing (required)
import Models.Location exposing (Location, locationDecoder)


type alias Bus =
    { id : Int
    , numberPlate : String
    , seats_available : Int
    , vehicleType : VehicleType
    , stated_milage : Float
    , route : Maybe Route
    , device : Maybe Device
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


type alias Student =
    { id : String
    , name : String
    }


type VehicleType
    = Van
    | Shuttle
    | SchoolBus


vehicleTypeToString vehicleType =
    case vehicleType of
        Van ->
            "van"

        Shuttle ->
            "shuttle"

        SchoolBus ->
            "bus"


busDecoderWithCallback : (Bus -> a) -> Decoder a
busDecoderWithCallback callback =
    let
        busDataDecoder id number_plate seats_available vehicle_type stated_milage route device update =
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
                    Bus id number_plate seats_available vehicleType stated_milage route device lastSeen
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
        |> required "last_seen" (nullable locationUpdateDecoder)
        |> Json.Decode.Pipeline.resolve


busDecoder : Decoder Bus
busDecoder =
    busDecoderWithCallback identity


routeDecoder : Decoder Route
routeDecoder =
    Decode.succeed Route
        |> required "id" string
        |> required "name" string


locationUpdateDecoder : Decoder LocationUpdate
locationUpdateDecoder =
    Decode.succeed LocationUpdate
        |> Json.Decode.Pipeline.hardcoded 0
        |> required "location" locationDecoder
        |> required "speed" float
        |> required "bearing" float
