module Api.Endpoint exposing (Endpoint, bus, buses, crewAssignmentChanges, crewMembers, crewMembersAndBuses, devices, get, households, login, patch, post, signup, trips)

import Http exposing (Body)
import Json.Decode exposing (Decoder, string)
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
    url [ "auth", "manager", "login" ] []


signup : Endpoint
signup =
    url [ "school", "create" ] []


crewMembers : Endpoint
crewMembers =
    url [ "school", "crew" ] []


crewMembersAndBuses : Endpoint
crewMembersAndBuses =
    url [ "school", "crew_and_buses" ] []


crewAssignmentChanges : Endpoint
crewAssignmentChanges =
    url [ "school", "crew_and_buses" ] []


households : Endpoint
households =
    url [ "school", "households" ] []


trips : { bus | bus_id : Int } -> Endpoint
trips { bus_id } =
    url [ "trips" ]
        [ Url.Builder.string "bus_id" (String.fromInt bus_id)
        ]


buses : Endpoint
buses =
    url [ "school", "buses" ] []


bus : Int -> Endpoint
bus busID =
    url [ "school", "buses", String.fromInt busID ]
        []


devices : Endpoint
devices =
    url [ "school", "devices" ] []



-- PRIVATE


unwrap : Endpoint -> String
unwrap (Endpoint str) =
    str


url : List String -> List QueryParameter -> Endpoint
url paths queryParams =
    Url.Builder.absolute ("api" :: paths) queryParams
        |> Endpoint
