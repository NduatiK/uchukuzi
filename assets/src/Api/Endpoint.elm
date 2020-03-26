module Api.Endpoint exposing (Endpoint, buses, createBus, createHousehold, devices, get, households, login, patch, post, registerDevice, signup, trips)

import Http exposing (Body)
import Json.Decode as Decode exposing (Decoder, bool, float, int, list, nullable, string)
import RemoteData exposing (RemoteData(..), WebData)
import Session exposing (Session)
import Url.Builder exposing (QueryParameter)


type Endpoint
    = Endpoint String


get : Endpoint -> Session -> Decoder a -> Cmd (WebData a)
get endpoint session decoder =
    Http.request
        { method = "GET"
        , headers = Session.authHeader session
        , url = unwrap endpoint
        , body = Http.emptyBody
        , expect = Http.expectJson decoder
        , timeout = Nothing
        , withCredentials = False
        }
        |> RemoteData.sendRequest


post : Endpoint -> Session -> Body -> Decoder a -> Cmd (WebData a)
post endpoint session body decoder =
    Http.request
        { method = "POST"
        , headers = Session.authHeader session
        , url = unwrap endpoint
        , body = body
        , expect = Http.expectJson decoder
        , timeout = Nothing
        , withCredentials = False
        }
        |> RemoteData.sendRequest


patch : Endpoint -> Session -> Body -> Decoder a -> Cmd (WebData a)
patch endpoint session body decoder =
    Http.request
        { method = "PATCH"
        , headers = Session.authHeader session
        , url = unwrap endpoint
        , body = body
        , expect = Http.expectJson decoder
        , timeout = Nothing
        , withCredentials = False
        }
        |> RemoteData.sendRequest



-- ENDPOINTS


login : Endpoint
login =
    url [ "auth", "login" ] []


signup : Endpoint
signup =
    url [ "people", "managers" ] []


households : Endpoint
households =
    url [ "households" ] []


trips : { bus | bus_id : String } -> Endpoint
trips { bus_id } =
    url [ "trips" ]
        [ Url.Builder.string "bus_id" bus_id
        ]


buses : Endpoint
buses =
    url [ "buses" ] []


devices : Endpoint
devices =
    url [ "devices" ] []


registerDevice : String -> Endpoint
registerDevice imei =
    url [ "devices", imei ] []


createHousehold : Endpoint
createHousehold =
    url [ "households" ] []


createBus : Endpoint
createBus =
    url [ "buses" ] []



-- PRIVATE


unwrap : Endpoint -> String
unwrap (Endpoint str) =
    str


url : List String -> List QueryParameter -> Endpoint
url paths queryParams =
    Url.Builder.absolute ("api" :: paths) queryParams
        |> Endpoint
