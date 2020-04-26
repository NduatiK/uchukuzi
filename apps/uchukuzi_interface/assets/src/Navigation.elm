module Navigation exposing (LoginRedirect(..), Route(..), fromUrl, href, isPublicRoute, isSamePage, pushUrl, replaceUrl, rerouteTo)

import Browser.Navigation as Nav
import Html exposing (Attribute)
import Html.Attributes as Attr
import Json.Decode as Decode exposing (Decoder)
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
    | Logout
    | Activate String
    | Login (Maybe LoginRedirect)
    | Signup
      -------------
    | Routes
    | CreateRoute
      -------------
    | CrewMembers
    | CrewMemberRegistration
    | EditCrewMember Int
      -------------
    | HouseholdList
    | StudentRegistration
      -------------
    | Buses
    | BusRegistration
    | EditBusDetails Int
    | Bus Int BusPage
    | BusDeviceRegistration Int
    | CreateBusRepair Int
    | CreateFuelReport Int



-------------
-- | DeviceList
-- http://localhost:4000/#/fleet/1/?page=trips
--  Parser.map Bus (s (routeName Buses) </> int <?> Query.string "page")


loggedInParser : Parser (Route -> a) a
loggedInParser =
    oneOf
        (Parser.map Buses Parser.top
            :: parsersFor
                [ Buses
                , Routes
                , HouseholdList

                -- , DeviceList
                , CrewMembers
                ]
            ++ [ Parser.map CreateFuelReport (s (routeName Buses) </> int </> s (busPageToString FuelHistory) </> s (routeName (CreateFuelReport -1)))
               , Parser.map CreateBusRepair (s (routeName Buses) </> int </> s (busPageToString BusRepairs) </> s (routeName (CreateBusRepair -1)))
               , Parser.map CreateRoute (s (routeName Routes) </> s (routeName CreateRoute))
               , Parser.map EditCrewMember (s (routeName CrewMembers) </> int </> s (routeName (EditCrewMember -1)))
               , Parser.map EditBusDetails (s (routeName Buses) </> int </> s (routeName (EditBusDetails -1)))
               , Parser.map BusDeviceRegistration (s (routeName Buses) </> int </> s (routeName (BusDeviceRegistration -1)))
               ]
            ++ parsersFor2
                [ ( HouseholdList, StudentRegistration )
                , ( CrewMembers, CrewMemberRegistration )
                , ( Buses, BusRegistration )

                -- , ( DeviceList, DeviceRegistration )
                ]
            ++ [ Parser.map (\a -> Bus a About) (s (routeName Buses) </> int)
               , Parser.map
                    (\a b ->
                        let
                            matching =
                                List.head (List.filter (\p -> busPageToString p == b) allBusPages)
                        in
                        Bus a (Maybe.withDefault About matching)
                    )
                    (s (routeName Buses) </> int </> string)
               ]
        )


notLoggedInParser : Parser (Route -> a) a
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



-- buildParser : Route -> Parser (String -> )Route


parsersFor : List Route -> List (Parser (Route -> c) c)
parsersFor routes =
    List.map buildParser routes


parsersFor2 : List ( Route, Route ) -> List (Parser (Route -> c) c)
parsersFor2 routes =
    List.map
        (\r -> Parser.map (Tuple.second r) (s (routeName (Tuple.first r)) </> s (routeName (Tuple.second r))))
        routes


buildParser route =
    Parser.map route (s (routeName route))


loginUrlParser : Parser (Maybe LoginRedirect -> a) a
loginUrlParser =
    -- Parser.custom "String" (\str -> Just str)
    Parser.custom "loginUrlParser" (stringToLoginRedirect >> Just)



-- PUBLIC HELPERS


href : Route -> String
href targetRoute =
    routeToString targetRoute


{-| replaceUrl : Key -> String -> Cmd msg
Change the URL, but do not trigger a page load.

This will not add a new entry to the browser history.

This can be useful if you have search box and you want the ?search=hats in
the URL to match without adding a history entry for every single key
stroke. Imagine how annoying it would be to click back
thirty times and still be on the same page!

-}
replaceUrl : Nav.Key -> Route -> Cmd msg
replaceUrl key route =
    Nav.replaceUrl key (routeToString route)


{-| Change the URL, but do not trigger a page load.

This will add a new entry to the browser history.

**Note:** If the user has gone `back` a few pages, there will be &ldquo;future
pages&rdquo; that the user can go `forward` to. Adding a new URL in that
scenario will clear out any future pages. It is like going back in time and
making a different choice.

-}
pushUrl : Nav.Key -> Route -> Cmd msg
pushUrl key route =
    Nav.pushUrl key (routeToString route)


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


isSamePage : Url -> Url -> Bool
isSamePage url1 url2 =
    case ( Parser.parse loggedInParser (parseUrl url1), Parser.parse loggedInParser (parseUrl url2) ) of
        ( Nothing, Nothing ) ->
            Parser.parse notLoggedInParser (parseUrl url1) == Parser.parse notLoggedInParser (parseUrl url2)

        ( Just (Bus a _), Just (Bus b _) ) ->
            a == b

        ( a, b ) ->
            a == b


fromUrl : Url -> Session -> Maybe Route
fromUrl url session =
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

                Logout ->
                    [ routeName page ]

                Signup ->
                    [ routeName page ]

                HouseholdList ->
                    [ routeName page ]

                StudentRegistration ->
                    [ routeName HouseholdList, routeName page ]

                -- DeviceList ->
                --     [ routeName page ]
                BusDeviceRegistration busID ->
                    [ routeName Buses, String.fromInt busID, routeName page ]

                Buses ->
                    [ routeName Buses ]

                Bus busID busPage ->
                    [ routeName Buses, String.fromInt busID, busPageToString busPage ]

                BusRegistration ->
                    [ routeName Buses, routeName BusRegistration ]

                EditBusDetails id ->
                    [ routeName Buses, String.fromInt id, routeName page ]

                CreateBusRepair busID ->
                    [ routeName Buses, String.fromInt busID, busPageToString BusRepairs, routeName (CreateBusRepair -1) ]

                CreateFuelReport busID ->
                    [ routeName Buses, String.fromInt busID, busPageToString FuelHistory, routeName (CreateFuelReport -1) ]

                Routes ->
                    [ routeName Routes ]

                CreateRoute ->
                    [ routeName Routes, routeName CreateRoute ]

                CrewMembers ->
                    [ routeName CrewMembers ]

                CrewMemberRegistration ->
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

        Activate _ ->
            "activate"

        Login _ ->
            "login"

        Logout ->
            "logout"

        Signup ->
            "signup"

        HouseholdList ->
            "students"

        BusDeviceRegistration _ ->
            "register_device"

        StudentRegistration ->
            "new"

        Buses ->
            "fleet"

        Bus _ _ ->
            "fleet"

        BusRegistration ->
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

        CrewMembers ->
            "crew"

        CrewMemberRegistration ->
            "new"

        EditCrewMember _ ->
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
