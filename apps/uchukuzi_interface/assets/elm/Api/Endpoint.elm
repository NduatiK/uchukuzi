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
    , delete
    , deleteItems
    , devices
    , editSchoolLocation
    , fuelReports
    , get
    , household
    , households
    , login
    , newRouteFromTrip
    , ongoingTrip
    , patch
    , performedBusRepairs
    , post
    , reportsForTrip
    , route
    , routeForBus
    , routes
    , routesAvailableForBus
    , schoolDetails
    , schoolDeviationRadius
    , signup
    , studentsOnboard
    , trips
    , updatePassword
    , updateRouteFromTrip
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


delete : Endpoint -> Session -> Decoder a -> Cmd (WebData a)
delete endpoint session decoder =
    Http.request
        { method = "DELETE"
        , headers = Session.authHeader session
        , url = unwrap endpoint
        , body = Http.emptyBody
        , expect = Http.expectJson decoder
        , timeout = Nothing
        , withCredentials = False
        }
        |> RemoteData.sendRequest


deleteItems : Endpoint -> Session -> Body -> Decoder a -> Cmd (WebData a)
deleteItems endpoint session body decoder =
    Http.request
        { method = "DELETE"
        , headers = Session.authHeader session
        , url = unwrap endpoint
        , body = body
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


updatePassword : Endpoint
updatePassword =
    url [ "auth", "manager", "update_password" ] []


activate : Endpoint
activate =
    url [ "auth", "manager", "exchange_token" ] []


schoolDetails : Endpoint
schoolDetails =
    url [ "school", "details" ] []


schoolDeviationRadius : Endpoint
schoolDeviationRadius =
    url [ "school", "details", "deviationRadius" ] []


signup : Endpoint
signup =
    url [ "school", "create" ] []


editSchoolLocation : Endpoint
editSchoolLocation =
    url [ "school", "edit_location" ] []


crewMember : Int -> Endpoint
crewMember id =
    url [ "school", "crew", String.fromInt id ] []


route : Int -> Endpoint
route id =
    url [ "school", "routes", String.fromInt id ] []


updateRouteFromTrip : Int -> Endpoint
updateRouteFromTrip id =
    url [ "school", "routes", String.fromInt id, "from_trip" ] []


newRouteFromTrip : Endpoint
newRouteFromTrip =
    url [ "school", "routes", "from_trip" ] []


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


trips : Int -> Endpoint
trips bus_id =
    url [ "school", "buses", String.fromInt bus_id, "trips" ]
        []


ongoingTrip : Int -> Endpoint
ongoingTrip bus_id =
    url [ "school", "buses", String.fromInt bus_id, "trips", "ongoing" ]
        []


reportsForTrip : Int -> Endpoint
reportsForTrip tripID =
    url [ "school", "trips", String.fromInt tripID ]
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
    url [ "school", "routes_available" ]
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
