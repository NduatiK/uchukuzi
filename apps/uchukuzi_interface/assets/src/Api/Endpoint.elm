module Api.Endpoint exposing
    ( Endpoint
    , activate
    , bus
    , buses
    , crewAssignmentChanges
    , crewMember
    , crewMembers
    , crewMembersAndBuses
    , crewMembersForBus
    , devices
    , fuelReports
    , get
    , household
    , households
    , login
    , patch
    , performedBusRepairs
    , post
    , routeForBus
    , routes
    , routesAvailableForBus
    , signup
    , studentsOnboard
    , trips
    )

import Http exposing (Body)
import Json.Decode exposing (Decoder)
import RemoteData exposing (RemoteData(..), WebData)
import Session exposing (Session)
import Url.Builder exposing (QueryParameter, int)


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


activate : Endpoint
activate =
    url [ "auth", "manager", "exchange_token" ] []


signup : Endpoint
signup =
    url [ "school", "create" ] []


crewMember : Int -> Endpoint
crewMember id =
    url [ "school", "crew", String.fromInt id ] []


crewMembers : Endpoint
crewMembers =
    url [ "school", "crew" ] []


crewMembersAndBuses : Endpoint
crewMembersAndBuses =
    url [ "school", "crew_and_buses" ] []


crewAssignmentChanges : Endpoint
crewAssignmentChanges =
    url [ "school", "crew_and_buses" ] []


household : Int -> Endpoint
household id =
    url [ "school", "households", String.fromInt id ] []


households : Endpoint
households =
    url [ "school", "households" ] []


trips : { bus | bus_id : Int } -> Endpoint
trips { bus_id } =
    url [ "tracking", "trips", String.fromInt bus_id ]
        []


buses : Endpoint
buses =
    url [ "school", "buses" ] []


bus : Int -> Endpoint
bus busID =
    url [ "school", "buses", String.fromInt busID ]
        []


performedBusRepairs : Int -> Endpoint
performedBusRepairs busID =
    url [ "school", "buses", String.fromInt busID, "performed_repairs" ]
        []


fuelReports : Int -> Endpoint
fuelReports busID =
    url [ "school", "buses", String.fromInt busID, "fuel_reports" ]
        []


crewMembersForBus : Int -> Endpoint
crewMembersForBus busID =
    url [ "school", "buses", String.fromInt busID, "crew" ]
        []


studentsOnboard : Int -> Endpoint
studentsOnboard busID =
    url [ "school", "buses", String.fromInt busID, "students_onboard" ]
        []


devices : Endpoint
devices =
    url [ "school", "devices" ] []


routes : Endpoint
routes =
    url [ "school", "routes" ] []


routeForBus : Int -> Endpoint
routeForBus busID =
    url [ "school", "buses", String.fromInt busID, "route" ] []


routesAvailableForBus : Maybe Int -> Endpoint
routesAvailableForBus busID =
    url [ "school", "routes", "routes_available" ]
        (case busID of
            Just id ->
                [ int "bus_id" id ]

            Nothing ->
                []
        )



-- PRIVATE


unwrap : Endpoint -> String
unwrap (Endpoint str) =
    str


url : List String -> List QueryParameter -> Endpoint
url paths queryParams =
    Url.Builder.absolute ("api" :: paths) queryParams
        |> Endpoint
