module Route exposing (LoginRedirect(..), Route(..), fromUrl, href, isPublicRoute, replaceUrl, rerouteTo)

import Browser.Navigation as Nav
import Html exposing (Attribute)
import Html.Attributes as Attr
import Json.Decode as Decode exposing (Decoder)
import Session exposing (Session)
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser, int, oneOf, s, string)



-- ROUTING


type LoginRedirect
    = ConfirmEmail


type Route
    = Home
    | StudentRegistration
    | Login (Maybe LoginRedirect)
    | Logout
    | Signup
    | Dashboard
    | HouseholdList
    | Buses
    | BusRegistration
    | Bus Int
    | DeviceList
    | DeviceRegistration



-- = Home
-- | Root
-- | Login
-- | Logout
-- | Register
-- | Settings
-- | Article Slug
-- | Profile Username
-- | NewArticle
-- | EditArticle Slug


loggedInParser : Parser (Route -> a) a
loggedInParser =
    oneOf
        [ buildParser Dashboard
        , buildParser HouseholdList
        , Parser.map StudentRegistration (s (routeName HouseholdList) </> s (routeName StudentRegistration))
        , buildParser Buses
        , Parser.map Bus (s (routeName (Bus 0)) </> int)
        , Parser.map BusRegistration (s (routeName Buses) </> s (routeName BusRegistration))
        , buildParser DeviceList
        , Parser.map DeviceRegistration (s (routeName DeviceList) </> s (routeName DeviceRegistration))
        ]


notLoggedInParser : Parser (Route -> a) a
notLoggedInParser =
    oneOf
        [ buildParser (Login Nothing)
        , Parser.map Login (s (routeName (Login Nothing)) </> loginUrlParser)
        , buildParser Signup
        ]


publicParser : Parser (Route -> a) a
publicParser =
    oneOf
        [ Parser.map Home Parser.top
        ]


isPublicRoute : Maybe Route -> Bool
isPublicRoute route =
    case route of
        Nothing ->
            False

        Just aRoute ->
            List.member aRoute [ Home ]



-- buildParser : Route -> Parser


buildParser route =
    Parser.map route (s (routeName route))



-- busUrlParser : Parser (String -> a) a
-- busUrlParser =
--     Parser.custom "String" (\str -> Just str)


loginUrlParser : Parser (Maybe LoginRedirect -> a) a
loginUrlParser =
    -- Parser.custom "String" (\str -> Just str)
    Parser.custom "loginUrlParser" (stringToLoginRedirect >> Just)



-- PUBLIC HELPERS


href : Route -> String
href targetRoute =
    routeToString targetRoute


replaceUrl : Nav.Key -> Route -> Cmd msg
replaceUrl key route =
    Nav.replaceUrl key (routeToString route)


fromUrl : Url -> Session -> Maybe Route
fromUrl url session =
    let
        path =
            { url | path = Maybe.withDefault "" url.fragment, fragment = Nothing }

        loggedInRoute =
            Parser.parse loggedInParser path

        publicRoute =
            Parser.parse publicParser path

        guestRoute =
            Parser.parse notLoggedInParser path
    in
    if publicRoute /= Nothing then
        -- Always match the public route
        publicRoute

    else if Session.isGuest session then
        case ( guestRoute, loggedInRoute ) of
            ( Just matchedGuestRoute, _ ) ->
                Just matchedGuestRoute

            ( _, Just matchedLoggedInRoute ) ->
                -- Redirect url cheats to Login
                Just (Login Nothing)

            ( Nothing, Nothing ) ->
                Nothing

    else
        case ( guestRoute, loggedInRoute ) of
            ( Just _, _ ) ->
                -- Redirect non guests to login
                Just Dashboard

            ( _, Just matchedLoggedInRoute ) ->
                Just matchedLoggedInRoute

            ( Nothing, Nothing ) ->
                Nothing


rerouteTo : { a | session : Session } -> Route -> Cmd msg
rerouteTo a route =
    Nav.pushUrl
        (Session.navKey a.session)
        (routeToString route)



-- INTERNAL


routeToString : Route -> String
routeToString page =
    let
        pieces =
            case page of
                Home ->
                    []

                Dashboard ->
                    [ routeName page ]

                Login redirect ->
                    [ routeName page, loginRedirectToString redirect ]

                Logout ->
                    [ routeName page ]

                Signup ->
                    [ routeName page ]

                HouseholdList ->
                    [ routeName page ]

                StudentRegistration ->
                    [ routeName HouseholdList, routeName page ]

                DeviceList ->
                    [ routeName page ]

                DeviceRegistration ->
                    [ routeName DeviceList, routeName page ]

                Buses ->
                    [ routeName Buses ]

                Bus busID ->
                    [ routeName Buses, String.fromInt busID ]

                BusRegistration ->
                    [ routeName Buses, routeName BusRegistration ]
    in
    "#/" ++ String.join "/" pieces


routeName : Route -> String
routeName page =
    case page of
        Home ->
            ""

        Dashboard ->
            "dashboard"

        Login _ ->
            "login"

        Logout ->
            "logout"

        Signup ->
            "signup"

        HouseholdList ->
            "students"

        DeviceList ->
            "devices"

        DeviceRegistration ->
            "new"

        StudentRegistration ->
            "new"

        Buses ->
            "fleet"

        Bus _ ->
            "fleet"

        BusRegistration ->
            "new"


loginRedirectToString : Maybe LoginRedirect -> String
loginRedirectToString redirect =
    case redirect of
        Nothing ->
            ""

        Just ConfirmEmail ->
            "confirmEmail"


stringToLoginRedirect : String -> Maybe LoginRedirect
stringToLoginRedirect string =
    case string of
        "confirmEmail" ->
            Just ConfirmEmail

        _ ->
            Nothing
