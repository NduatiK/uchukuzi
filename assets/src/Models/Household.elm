module Models.Household exposing (Household, Location, Student, householdDecoder)

import Json.Decode as Decode exposing (Decoder, float, int, list, nullable, string, succeed)
import Json.Decode.Pipeline exposing (optional, required, resolve)


type alias Household =
    { id : Int
    , guardian : Guardian
    , students : List Student
    }


type alias Guardian =
    { id : Int
    , name : String
    , phoneNumber : String
    , email : String
    }


householdDecoder : Decoder Household
householdDecoder =
    let
        decoder id name email phoneNumber students =
            succeed (Household id (Guardian id name email phoneNumber) students)
    in
    Decode.succeed decoder
        |> required "id" int
        |> required "name" string
        |> required "email" string
        |> required "phone_number" string
        |> required "students" (list studentDecoder)
        |> resolve


type alias Student =
    { name : String
    , travel_time : String
    , homeLocation : Location
    , pickupLocation : Location
    , route : String
    }


type alias Location =
    { lng : Float
    , lat : Float
    }


studentDecoder : Decoder Student
studentDecoder =
    Decode.succeed Student
        |> required "name" string
        |> required "travel_time" string
        |> required "home_location" locationDecoder
        |> required "pickup_location" locationDecoder
        |> required "route" string


locationDecoder : Decoder Location
locationDecoder =
    Decode.succeed Location
        |> required "lng" float
        |> required "lat" float
