module Session exposing (Cred, Session, authHeader, fromCredentials, getCredentials, isGuest, navKey, timeZone, toGuest, withCredentials, withTimeZone)

import Browser.Navigation as Nav
import Http
import Time



-- TYPES


type Session
    = LoggedIn Nav.Key Time.Zone Cred
    | Guest Nav.Key Time.Zone


type alias Cred =
    { name : String
    , email : String
    , token : String
    , school_id : Int
    }


getCredentials : Session -> Maybe Cred
getCredentials session =
    case session of
        LoggedIn _ _ credentials ->
            Just credentials

        Guest _ _ ->
            Nothing


navKey : Session -> Nav.Key
navKey session =
    case session of
        LoggedIn key _ _ ->
            key

        Guest key _ ->
            key


timeZone : Session -> Time.Zone
timeZone session =
    case session of
        LoggedIn _ timezone _ ->
            timezone

        Guest _ timezone ->
            timezone


withTimeZone : Session -> Time.Zone -> Session
withTimeZone session newTimeZone =
    case session of
        LoggedIn key _ credentials ->
            LoggedIn key newTimeZone credentials

        Guest key _ ->
            Guest key newTimeZone


fromCredentials : Nav.Key -> Time.Zone -> Maybe Cred -> Session
fromCredentials key timezone credentials_ =
    case credentials_ of
        Nothing ->
            Guest key timezone

        Just credentials ->
            LoggedIn key timezone credentials


withCredentials : Session -> Maybe Cred -> Session
withCredentials session maybeCredentials =
    case maybeCredentials of
        Nothing ->
            Guest (navKey session) (timeZone session)

        Just credentials ->
            case session of
                LoggedIn key timezone _ ->
                    LoggedIn key timezone credentials

                Guest key timezone ->
                    LoggedIn key timezone credentials


toGuest : Session -> Session
toGuest session =
    case session of
        LoggedIn key timezone _ ->
            Guest key timezone

        _ ->
            session


authHeader : Session -> List Http.Header
authHeader session =
    case getCredentials session of
        Nothing ->
            []

        Just { token } ->
            [ Http.header "authorization" ("Bearer " ++ token) ]


isGuest : Session -> Bool
isGuest session =
    getCredentials session == Nothing
