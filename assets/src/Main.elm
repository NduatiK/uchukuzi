module Main exposing (..)

import Api
import Browser
import Browser.Events
import Browser.Navigation as Nav
import Element exposing (..)
import Html.Attributes exposing (src)
import Json.Decode exposing (Value)
import Page exposing (..)
import Pages.Blank
import Pages.Buses.BusPage as BusDetailsPage
import Pages.Buses.BusRegistrationPage as BusRegistration
import Pages.Buses.BusesPage as BusesList
import Pages.DashboardPage as Dashboard
import Pages.Devices.DeviceRegistrationPage as DeviceRegistration
import Pages.Devices.DevicesPage as DevicesList
import Pages.Home as Home
import Pages.Households.HouseholdRegistrationPage as StudentRegistration
import Pages.Households.HouseholdsPage as HouseholdList
import Pages.Login as Login
import Pages.Logout as Logout
import Pages.NotFound as NotFound
import Pages.Signup as Signup
import Route exposing (Route)
import Session exposing (Session)
import Style
import Template.NavBar as NavBar exposing (viewHeader)
import Time
import Url



---- MODEL ----


type alias Model =
    { page : PageModel
    , route : Maybe Route
    , navState : NavBar.Model
    , windowHeight : Int
    }


{-| Make sure to extend the updatePage method when you add a page
-}
type PageModel
    = Redirect Session
    | NotFound Session
    | Home Home.Model
    | Dashboard Dashboard.Model
    | Login Login.Model
    | Logout Logout.Model
    | HouseholdList HouseholdList.Model
    | StudentRegistration StudentRegistration.Model
    | BusesList BusesList.Model
    | BusDetailsPage BusDetailsPage.Model
    | BusRegistration BusRegistration.Model
    | DevicesList DevicesList.Model
    | Signup Signup.Model
    | DeviceRegistration DeviceRegistration.Model


init : Maybe Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init args url navKey =
    let
        creds =
            Maybe.andThen
                (\x ->
                    case
                        Json.Decode.decodeValue
                            (Json.Decode.at [ "state" ] Api.credDecoder)
                            x
                    of
                        Ok a ->
                            Just a

                        _ ->
                            Nothing
                )
                args

        height =
            Maybe.withDefault 100
                (Maybe.andThen
                    (\x ->
                        case
                            Json.Decode.decodeValue
                                (Json.Decode.at [ "window", "height" ] Json.Decode.int)
                                x
                        of
                            Ok a ->
                                Just a

                            _ ->
                                Nothing
                    )
                    args
                )

        session =
            Session.fromCredentials navKey Time.utc creds
    in
    changeRouteTo (Route.fromUrl url session)
        (Model
            (Redirect session)
            Nothing
            (NavBar.init session)
            height
        )



---- UPDATE ----


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | ReceivedCreds (Maybe Session.Cred)
    | WindowResized Int Int
      ------------
      -- | UpdatedSessionCred (Maybe Session.Cred)
      ------------
    | GotNavBarMsg NavBar.Msg
      ------------
    | GotHouseholdListMsg HouseholdList.Msg
    | GotHomeMsg ()
    | GotLoginMsg Login.Msg
    | GotLogoutMsg ()
    | GotSignupMsg Signup.Msg
      ------------
    | GotBusesListMsg BusesList.Msg
    | GotBusDetailsPageMsg BusDetailsPage.Msg
    | GotBusRegistrationMsg BusRegistration.Msg
      ------------
    | GotStudentRegistrationMsg StudentRegistration.Msg
    | GotDashboardMsg Dashboard.Msg
    | GotDevicesListMsg DevicesList.Msg
    | GotDeviceRegistrationMsg DeviceRegistration.Msg



---- VIEW ----


view : Model -> Browser.Document Msg
view { page, route, navState, windowHeight } =
    let
        viewEmptyPage pageContents =
            viewPage pageContents GotHomeMsg

        viewPage pageContents toMsg =
            Page.frame route pageContents (toSession page) toMsg navState GotNavBarMsg windowHeight

        -- viewEmptyPage =
        renderedView =
            case page of
                Home _ ->
                    viewEmptyPage Home.view

                Login model ->
                    viewPage (Login.view model) GotLoginMsg

                Signup model ->
                    viewPage (Signup.view model) GotSignupMsg

                Redirect _ ->
                    viewEmptyPage Pages.Blank.view

                Logout _ ->
                    viewEmptyPage Pages.Blank.view

                NotFound _ ->
                    viewEmptyPage NotFound.view

                Dashboard model ->
                    viewPage (Dashboard.view model) GotDashboardMsg

                HouseholdList model ->
                    viewPage (HouseholdList.view model) GotHouseholdListMsg

                StudentRegistration model ->
                    viewPage (StudentRegistration.view model) GotStudentRegistrationMsg

                BusesList model ->
                    viewPage (BusesList.view model) GotBusesListMsg

                BusRegistration model ->
                    viewPage (BusRegistration.view model) GotBusRegistrationMsg

                BusDetailsPage model ->
                    viewPage (BusDetailsPage.view model) GotBusDetailsPageMsg

                DevicesList model ->
                    viewPage (DevicesList.view model) GotDevicesListMsg

                DeviceRegistration model ->
                    viewPage (DeviceRegistration.view model) GotDeviceRegistrationMsg
    in
    { title = "Uchukuzi"
    , body =
        [ Element.layoutWith
            { options =
                [ focusStyle
                    { borderColor = Nothing
                    , backgroundColor = Nothing
                    , shadow = Nothing
                    }
                ]
            }
            Style.textFontStyle
            renderedView
        ]
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        WindowResized _ height ->
            ( { model | windowHeight = height }, Cmd.none )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    case url.fragment of
                        Nothing ->
                            ( model, Cmd.none )

                        Just _ ->
                            ( model
                            , Nav.pushUrl (Session.navKey (toSession model.page)) (Url.toString url)
                            )

                Browser.External href ->
                    ( model
                    , Nav.load href
                    )

        UrlChanged url ->
            changeRouteTo (Route.fromUrl url (toSession model.page)) model

        ReceivedCreds cred ->
            let
                session =
                    Session.withCredentials (toSession model.page) cred
            in
            if cred == Nothing then
                changeRouteWithUpdatedSessionTo (Just (Route.Login Nothing)) model session

            else
                changeRouteWithUpdatedSessionTo (Just Route.Dashboard) model session

        _ ->
            updatePage msg model


updatePage : Msg -> Model -> ( Model, Cmd Msg )
updatePage page_msg fullModel =
    let
        modelMapper : PageModel -> Model
        modelMapper pageModel =
            { fullModel | page = pageModel }

        mapModelAndMsg pageModelMapper pageMsgMapper ( subModel, subCmd ) =
            Page.transformToModelMsg (pageModelMapper >> modelMapper) pageMsgMapper ( subModel, subCmd )
    in
    case ( page_msg, fullModel.page ) of
        ( GotNavBarMsg msg, _ ) ->
            let
                ( newNavState, navMsg ) =
                    NavBar.update msg fullModel.navState
            in
            ( { fullModel | navState = newNavState }
            , Cmd.map GotNavBarMsg navMsg
            )

        ( GotHouseholdListMsg msg, HouseholdList model ) ->
            HouseholdList.update msg model
                |> mapModelAndMsg HouseholdList GotHouseholdListMsg

        ( GotBusesListMsg msg, BusesList model ) ->
            BusesList.update msg model
                |> mapModelAndMsg BusesList GotBusesListMsg

        ( GotBusRegistrationMsg msg, BusRegistration model ) ->
            BusRegistration.update msg model
                |> mapModelAndMsg BusRegistration GotBusRegistrationMsg

        ( GotBusDetailsPageMsg msg, BusDetailsPage model ) ->
            BusDetailsPage.update msg model
                |> mapModelAndMsg BusDetailsPage GotBusDetailsPageMsg

        ( GotStudentRegistrationMsg msg, StudentRegistration model ) ->
            StudentRegistration.update msg model
                |> mapModelAndMsg StudentRegistration GotStudentRegistrationMsg

        ( GotDevicesListMsg msg, DevicesList model ) ->
            DevicesList.update msg model
                |> mapModelAndMsg DevicesList GotDevicesListMsg

        ( GotLoginMsg msg, Login model ) ->
            Login.update msg model
                |> mapModelAndMsg Login GotLoginMsg

        ( GotSignupMsg msg, Signup model ) ->
            Signup.update msg model
                |> mapModelAndMsg Signup GotSignupMsg

        ( GotDeviceRegistrationMsg msg, DeviceRegistration model ) ->
            DeviceRegistration.update msg model
                |> mapModelAndMsg DeviceRegistration GotDeviceRegistrationMsg

        ( _, _ ) ->
            ( fullModel, Cmd.none )


getSession : Model -> Session
getSession model =
    toSession model.page


toSession : PageModel -> Session
toSession pageModel =
    case pageModel of
        Home home ->
            home.session

        Logout model ->
            model.session

        Login subModel ->
            subModel.session

        Signup subModel ->
            subModel.session

        Redirect session ->
            session

        NotFound session ->
            session

        Dashboard subModel ->
            subModel.session

        HouseholdList subModel ->
            subModel.session

        StudentRegistration subModel ->
            subModel.session

        BusesList subModel ->
            subModel.session

        BusRegistration subModel ->
            subModel.session

        BusDetailsPage subModel ->
            subModel.session

        DevicesList subModel ->
            subModel.session

        DeviceRegistration subModel ->
            subModel.session


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    let
        session =
            toSession model.page
    in
    changeRouteWithUpdatedSessionTo maybeRoute model session


changeRouteWithUpdatedSessionTo : Maybe Route -> Model -> Session -> ( Model, Cmd Msg )
changeRouteWithUpdatedSessionTo maybeRoute model session =
    let
        updateWith : (subModel -> PageModel) -> (subMsg -> Msg) -> ( subModel, Cmd subMsg ) -> ( PageModel, Cmd Msg )
        updateWith toModel toMsg ( subModel, subCmd ) =
            ( toModel subModel
            , Cmd.map toMsg subCmd
            )

        ( updatedPage, msg ) =
            case maybeRoute of
                Nothing ->
                    ( NotFound session, Cmd.none )

                Just Route.Home ->
                    Home.init session
                        |> updateWith Home GotHomeMsg

                Just Route.Buses ->
                    BusesList.init session (Page.viewHeight model.windowHeight)
                        |> updateWith BusesList GotBusesListMsg

                Just Route.BusRegistration ->
                    BusRegistration.init session
                        |> updateWith BusRegistration GotBusRegistrationMsg

                Just (Route.BusDeviceRegistration busID) ->
                    DeviceRegistration.init session (Just busID)
                        |> updateWith DeviceRegistration GotDeviceRegistrationMsg

                Just (Route.Bus busID) ->
                    BusDetailsPage.init busID session
                        |> updateWith BusDetailsPage GotBusDetailsPageMsg

                Just Route.Dashboard ->
                    Dashboard.init session
                        |> updateWith Dashboard GotDashboardMsg

                Just Route.HouseholdList ->
                    HouseholdList.init session
                        |> updateWith HouseholdList GotHouseholdListMsg

                Just Route.DeviceList ->
                    DevicesList.init session
                        |> updateWith DevicesList GotDevicesListMsg

                Just Route.DeviceRegistration ->
                    DeviceRegistration.init session Nothing
                        |> updateWith DeviceRegistration GotDeviceRegistrationMsg

                Just Route.StudentRegistration ->
                    StudentRegistration.init session
                        |> updateWith StudentRegistration GotStudentRegistrationMsg

                Just (Route.Login redirect) ->
                    Login.init session redirect
                        |> updateWith Login GotLoginMsg

                Just Route.Logout ->
                    Logout.init session
                        |> updateWith Logout GotLogoutMsg

                Just Route.Signup ->
                    Signup.init session
                        |> updateWith Signup GotSignupMsg
    in
    ( { model | page = updatedPage, route = maybeRoute }, msg )


subscriptions : Model -> Sub Msg
subscriptions model_ =
    let
        matching =
            case model_.page of
                DeviceRegistration model ->
                    Sub.map GotDeviceRegistrationMsg (DeviceRegistration.subscriptions model)

                Signup model ->
                    Sub.map GotSignupMsg (Signup.subscriptions model)

                _ ->
                    Sub.none
    in
    Sub.batch
        [ matching
        , Api.onStoreChange (Api.parseCreds >> ReceivedCreds)
        , Browser.Events.onResize WindowResized
        ]


main : Program (Maybe Value) Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }
