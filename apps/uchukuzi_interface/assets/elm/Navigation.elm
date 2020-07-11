module Navigation exposing
    ( LoginRedirect(..)
    , Route(..)
    , fromUrl
    , href
    , isPublicRoute
    , isSamePage
    , pushUrl
    , replaceUrl
    , rerouteTo
    , rerouteToString
    )

import Browser.Navigation as Nav
import Pages.Buses.Bus.Navigation exposing (BusPage(..), allBusPages)
import Session exposing (Session)
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), (<?>), Parser, int, oneOf, s, string)
import Url.Parser.Query as Query


busPageToString : BusPage -> String
busPageToString =
    Pages.Buses.Bus.Navigation.busPageToString >> String.toLower



-- ROUTING


type LoginRedirect
    = ConfirmEmail


type Route
    = Home
      -------------
    | Activate String
    | Login (Maybe LoginRedirect)
    | Signup
    | Settings
      -------------
    | Routes
    | CreateRoute
    | EditRoute Int
      -------------
    | CrewMembers
    | CreateCrewMember
    | EditCrewMember Int
      -------------
    | HouseholdList
    | EditHousehold Int
    | CreateHousehold
      -------------
    | Buses
    | CreateBusPage
    | EditBusDetails Int
    | Bus Int BusPage
    | BusDeviceRegistration Int
    | CreateBusRepair Int
    | CreateFuelReport Int


loggedInParser : Parser (Route -> Route) Route
loggedInParser =
    oneOf
        (Parser.map Buses Parser.top
            :: parsersFor
                [ Buses
                , Routes
                , HouseholdList
                , CrewMembers
                , Settings
                ]
            ++ [ Parser.map CreateRoute (s (routeName Routes) </> s (routeName CreateRoute))
               , Parser.map EditRoute (s (routeName Routes) </> int </> s (routeName (EditRoute -1)))

               -----
               , Parser.map CreateBusPage (s (routeName Buses) </> s (routeName CreateBusPage))
               , Parser.map CreateFuelReport (s (routeName Buses) </> int </> s (busPageToString FuelHistory) </> s (routeName (CreateFuelReport -1)))
               , Parser.map CreateBusRepair (s (routeName Buses) </> int </> s (busPageToString BusRepairs) </> s (routeName (CreateBusRepair -1)))
               , Parser.map EditBusDetails (s (routeName Buses) </> int </> s (routeName (EditBusDetails -1)))
               , Parser.map BusDeviceRegistration (s (routeName Buses) </> int </> s (routeName (BusDeviceRegistration -1)))

               -----
               , Parser.map (\busID -> Bus busID About) (s (routeName Buses) </> int)
               , Parser.map
                    (\busID pageName ->
                        -- Match bus subpage or default to bus about page
                        allBusPages
                            |> List.filter (\busPage -> busPageToString busPage == pageName)
                            |> List.head
                            |> Maybe.withDefault About
                            |> Bus busID
                    )
                    (s (routeName Buses) </> int </> string)

               -----
               , Parser.map CreateCrewMember (s (routeName CrewMembers) </> s (routeName CreateCrewMember))
               , Parser.map EditCrewMember (s (routeName CrewMembers) </> int </> s (routeName (EditCrewMember -1)))

               -----
               , Parser.map CreateHousehold (s (routeName HouseholdList) </> s (routeName CreateHousehold))
               , Parser.map EditHousehold (s (routeName HouseholdList) </> int </> s (routeName (EditHousehold -1)))
               ]
        )


notLoggedInParser : Parser (Route -> Route) Route
notLoggedInParser =
    oneOf
        [ Parser.map (\x -> Activate (Maybe.withDefault "" x)) (s (routeName (Activate "")) <?> Query.string "token")
        , buildParser (Login Nothing)
        , Parser.map Login (s (routeName (Login Nothing)) </> loginUrlParser)
        , buildParser Signup
        ]


publicParser : Parser (Route -> a) a
publicParser =
    oneOf
        -- [ Parser.map Home Parser.top
        []


isPublicRoute : Maybe Route -> Bool
isPublicRoute route =
    case route of
        Nothing ->
            False

        Just aRoute ->
            List.member aRoute [ Home ]


parsersFor : List Route -> List (Parser (Route -> Route) Route)
parsersFor routes =
    List.map buildParser routes


buildParser : Route -> Parser (Route -> Route) Route
buildParser route =
    Parser.map route (s (routeName route))


loginUrlParser : Parser (Maybe LoginRedirect -> a) a
loginUrlParser =
    Parser.custom "loginUrlParser" (stringToLoginRedirect >> Just)



-- PUBLIC HELPERS


href : Route -> String
href targetRoute =
    routeToString targetRoute


{-| replaceUrl : Key -> String -> Cmd msg
Change the URL, but do not trigger a page load.

This will not add a new entry to the browser history.

-}
replaceUrl : Nav.Key -> Route -> Cmd msg
replaceUrl key route =
    Nav.replaceUrl key (routeToString route)


{-| Change the URL, but do not trigger a page load.

This will add a new entry to the browser history.

-}
pushUrl : Nav.Key -> Route -> Cmd msg
pushUrl key route =
    Nav.pushUrl key (routeToString route)


isSamePage : Url -> Url -> Bool
isSamePage url1 url2 =
    case ( Parser.parse loggedInParser (parseUrl url1), Parser.parse loggedInParser (parseUrl url2) ) of
        ( Nothing, Nothing ) ->
            Parser.parse notLoggedInParser (parseUrl url1) == Parser.parse notLoggedInParser (parseUrl url2)

        ( Just (Bus a FuelHistory), Just (Bus b _) ) ->
            False

        ( Just (Bus a _), Just (Bus b _) ) ->
            a == b

        ( a, b ) ->
            a == b


parseUrl : Url -> Url
parseUrl url =
    let
        parts =
            case url.fragment of
                Just fragment ->
                    String.split "?" fragment

                Nothing ->
                    [ "", "" ]

        query =
            Maybe.withDefault "" (List.head (List.drop 1 parts))

        path =
            Maybe.withDefault "" (List.head parts)
    in
    { url | path = path, fragment = Nothing, query = Just query }


fromUrl : Session -> Url -> Maybe Route
fromUrl session url =
    let
        newUrl =
            parseUrl url

        loggedInRoute =
            Parser.parse loggedInParser newUrl

        publicRoute =
            Parser.parse publicParser newUrl

        guestRoute =
            Parser.parse notLoggedInParser newUrl
    in
    if publicRoute /= Nothing then
        -- Always match the public route
        publicRoute

    else if Session.isGuest session then
        case ( guestRoute, loggedInRoute ) of
            ( Just matchedGuestRoute, _ ) ->
                Just matchedGuestRoute

            ( _, Just _ ) ->
                -- Redirect url cheats to Login
                Just (Login Nothing)

            ( Nothing, Nothing ) ->
                Nothing

    else
        case ( guestRoute, loggedInRoute ) of
            ( Just _, _ ) ->
                -- Redirect non guests to login
                Just Buses

            ( _, Just matchedLoggedInRoute ) ->
                Just matchedLoggedInRoute

            ( Nothing, Nothing ) ->
                Nothing


rerouteTo : { a | session : Session } -> Route -> Cmd msg
rerouteTo a route =
    Nav.pushUrl
        (Session.navKey a.session)
        (routeToString route)


rerouteToString : { a | session : Session } -> String -> Cmd msg
rerouteToString a route =
    Nav.pushUrl (Session.navKey a.session) route



-- INTERNAL


routeToString : Route -> String
routeToString page =
    let
        pieces =
            case page of
                Home ->
                    []

                Activate _ ->
                    [ routeName page, "token" ]

                Login redirect ->
                    [ routeName page, loginRedirectToString redirect ]

                Settings ->
                    [ routeName page ]

                Signup ->
                    [ routeName page ]

                HouseholdList ->
                    [ routeName page ]

                CreateHousehold ->
                    [ routeName HouseholdList, routeName page ]

                EditHousehold guardianID ->
                    [ routeName HouseholdList, String.fromInt guardianID, routeName page ]

                BusDeviceRegistration busID ->
                    [ routeName Buses, String.fromInt busID, routeName page ]

                Buses ->
                    [ routeName Buses ]

                Bus busID busPage ->
                    [ routeName Buses, String.fromInt busID, busPageToString busPage ]

                CreateBusPage ->
                    [ routeName Buses, routeName CreateBusPage ]

                EditBusDetails id ->
                    [ routeName Buses, String.fromInt id, routeName page ]

                CreateBusRepair busID ->
                    [ routeName Buses, String.fromInt busID, busPageToString BusRepairs, routeName (CreateBusRepair -1) ]

                CreateFuelReport busID ->
                    [ routeName Buses, String.fromInt busID, busPageToString FuelHistory, routeName (CreateFuelReport -1) ]

                Routes ->
                    [ routeName Routes ]

                EditRoute id ->
                    [ routeName Routes, String.fromInt id, routeName page ]

                CreateRoute ->
                    [ routeName Routes, routeName CreateRoute ]

                CrewMembers ->
                    [ routeName CrewMembers ]

                CreateCrewMember ->
                    [ routeName CrewMembers, routeName page ]

                EditCrewMember id ->
                    [ routeName CrewMembers, String.fromInt id, "edit" ]
    in
    "#/" ++ String.join "/" pieces


routeName : Route -> String
routeName page =
    case page of
        Home ->
            ""

        Settings ->
            "settings"

        Activate _ ->
            "activate"

        Login _ ->
            "login"

        Signup ->
            "signup"

        HouseholdList ->
            "students"

        BusDeviceRegistration _ ->
            "register_device"

        CreateHousehold ->
            "new"

        Buses ->
            "fleet"

        Bus _ _ ->
            "fleet"

        CreateBusPage ->
            "new"

        EditBusDetails _ ->
            "edit"

        CreateBusRepair _ ->
            "new"

        CreateFuelReport _ ->
            "new"

        CreateRoute ->
            "new"

        Routes ->
            "routes"

        EditRoute _ ->
            "edit"

        CrewMembers ->
            "crew"

        CreateCrewMember ->
            "new"

        EditCrewMember _ ->
            "edit"

        EditHousehold _ ->
            "edit"


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
