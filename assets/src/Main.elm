module Main exposing (..)

import Api
import Browser
import Browser.Navigation as Nav
import Element exposing (..)
import Html.Attributes exposing (src)
import Json.Decode exposing (Value)
import Page exposing (..)
import Pages.Blank
import Pages.Buses.BusDetailsPage as BusDetailsPage
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
import Time
import Url



---- MODEL ----


type alias Model =
    { page : PageModel
    , route : Maybe Route
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
init maybeCreds url navKey =
    let
        creds =
            Api.parseCreds maybeCreds

        session =
            Session.fromCredentials navKey Time.utc creds
    in
    changeRouteTo (Route.fromUrl url session)
        (Model
            (Redirect session)
            Nothing
        )



---- UPDATE ----


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | ReceivedCreds (Maybe Session.Cred)
      ------------
      -- | UpdatedSessionCred (Maybe Session.Cred)
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
view { page, route } =
    let
        viewPage page_ toMsg pageContents =
            Element.map toMsg (Page.frame page_ pageContents (toSession page))

        -- viewEmptyPage =
        renderedView =
            case page of
                Home _ ->
                    Page.frame route Home.view (toSession page)

                Login model ->
                    viewPage route GotLoginMsg (Login.view model)

                Signup model ->
                    viewPage route GotSignupMsg (Signup.view model)

                Redirect _ ->
                    Page.frame route Pages.Blank.view (toSession page)

                Logout _ ->
                    Page.frame route Pages.Blank.view (toSession page)

                NotFound _ ->
                    Page.frame route NotFound.view (toSession page)

                Dashboard model ->
                    viewPage route GotDashboardMsg (Dashboard.view model)

                HouseholdList model ->
                    viewPage route GotHouseholdListMsg (HouseholdList.view model)

                StudentRegistration model ->
                    viewPage route GotStudentRegistrationMsg (StudentRegistration.view model)

                BusesList model ->
                    viewPage route GotBusesListMsg (BusesList.view model)

                BusRegistration model ->
                    viewPage route GotBusRegistrationMsg (BusRegistration.view model)

                BusDetailsPage model ->
                    viewPage route GotBusDetailsPageMsg (BusDetailsPage.view model)

                DevicesList model ->
                    viewPage route GotDevicesListMsg (DevicesList.view model)

                DeviceRegistration model ->
                    viewPage route GotDeviceRegistrationMsg (DeviceRegistration.view model)
    in
    { title = "Uchukuzi"
    , body =
        [ Element.layout Style.textFontStyle renderedView ]
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
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
                changeRouteWithUpdatedSessionTo model.route model session

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
                    BusesList.init session
                        |> updateWith BusesList GotBusesListMsg

                Just Route.BusRegistration ->
                    BusRegistration.init session
                        |> updateWith BusRegistration GotBusRegistrationMsg

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
                    DeviceRegistration.init session
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
    case model_.page of
        DeviceRegistration model ->
            -- receiveCameraActive
            Sub.map GotDeviceRegistrationMsg (DeviceRegistration.subscriptions model)

        _ ->
            Api.onStoreChange (Just >> Api.parseCreds >> ReceivedCreds)


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
