module Models.CrewMember exposing (Route, routeDecoder)

import Json.Decode as Decode exposing (Decoder, list, string)
import Json.Decode.Pipeline exposing (required)


type alias CrewMember =
    { id : Int
    , name : String
    , role : String
    , email : String
    , phoneNumber : String
    , bus : Maybe Int
    }
