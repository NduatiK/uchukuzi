module Models.Notification exposing (Notification, decoder)

import Element
import Icons
import Iso8601
import Json.Decode as Decode exposing (Decoder, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, optionalAt, required, resolve)
import Time


type alias Notification =
    { id : Int
    , title : String
    , content : String
    , seen : Bool
    , time : Time.Posix
    , redirectUrl : String
    }


decoder id =
    let
        decoder_ id_ title content dateTimeString redirectUrl =
            case Iso8601.toTime dateTimeString of
                Result.Ok dateTime ->
                    Decode.succeed
                        { title = title
                        , id = id_
                        , content = content
                        , time = dateTime
                        , seen = False
                        , redirectUrl = redirectUrl
                        }

                Result.Err _ ->
                    Decode.fail (dateTimeString ++ " cannot be decoded to a date")
    in
    Decode.succeed decoder_
        |> Json.Decode.Pipeline.hardcoded id
        |> required "title" string
        |> required "content" string
        |> required "time" string
        |> required "redirectUrl" string
        |> resolve
