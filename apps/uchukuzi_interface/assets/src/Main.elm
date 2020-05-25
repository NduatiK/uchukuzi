module Main exposing (..)

import Api
import Browser
import Browser.Events
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Element exposing (..)
import Html.Attributes
import Json.Decode exposing (Value)
import Models.Bus exposing (LocationUpdate)
import Navigation exposing (Route)
import Page exposing (..)
import Pages.Activate as Activate
import Pages.Blank
import Pages.Buses.Bus.CreateBusRepairPage as CreateBusRepair
import Pages.Buses.Bus.CreateFuelReport as CreateFuelReport
import Pages.Buses.BusPage as BusDetailsPage
import Pages.Buses.BusesPage as BusesList
import Pages.Buses.CreateBusPage as BusRegistration
import Pages.Crew.CrewMemberRegistrationPage as CrewMemberRegistration
import Pages.Crew.CrewMembersPage as CrewMembers
import Pages.Devices.DeviceRegistrationPage as DeviceRegistration
import Pages.ErrorPage as ErrorPage
import Pages.Home as Home
import Pages.Households.HouseholdRegistrationPage as StudentRegistration
import Pages.Households.HouseholdsPage as HouseholdList
import Pages.LoadingPage as LoadingPage
import Pages.Login as Login
import Pages.Logout as Logout
import Pages.NotFound as NotFound
import Pages.Routes.CreateRoutePage as CreateRoute
import Pages.Routes.Routes as RoutesList
import Pages.Settings as Settings
import Pages.Signup as Signup
import Ports
import Session exposing (Session)
import Style
import Task
import Template.NavBar as NavBar exposing (viewHeader)
import Template.SideBar as SideBar
import Template.TabBar as TabBar
import Time
import Url



---- MODEL ----


type alias Model =
    { page : PageModel
    , route : Maybe Route
    , navState : NavBar.Model
    , sideBarState : SideBar.Model
    , windowHeight : Int
    , url : Url.Url
    , locationUpdates : Dict Int LocationUpdate
    , allowReroute : Bool
    , loading : Bool
    , error : Bool
    }


{-| Make sure to extend the updatePage method when you add a page
-}
type PageModel
    = Redirect Session
    | NotFound Session
    | Home Home.Model
      -- | Dashboard Dashboard.Model
      ------------
    | Settings Settings.Model
    | Login Login.Model
    | Activate Activate.Model
    | Logout Logout.Model
    | Signup Signup.Model
      ------------
    | RoutesList RoutesList.Model
    | CreateRoute CreateRoute.Model
      ------------
    | HouseholdList HouseholdList.Model
    | StudentRegistration StudentRegistration.Model
      ------------
    | BusesList BusesList.Model
    | BusDetailsPage BusDetailsPage.Model
    | BusRegistration BusRegistration.Model
    | CreateBusRepair CreateBusRepair.Model
    | CreateFuelReport CreateFuelReport.Model
      ------------
      -- | DevicesList DevicesList.Model
      ------------
    | DeviceRegistration DeviceRegistration.Model
      ------------
    | CrewMembers CrewMembers.Model
    | CrewMemberRegistration CrewMemberRegistration.Model


init : Maybe Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init args url navKey =
    let
        creds =
            Maybe.andThen
                (\x ->
                    case
                        Json.Decode.decodeValue
                            (Json.Decode.at [ "credentials" ] Api.credDecoder)
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

        loading =
            Maybe.withDefault False
                (Maybe.andThen
                    (\x ->
                        Result.toMaybe
                            (Json.Decode.decodeValue
                                (Json.Decode.at [ "loading" ] Json.Decode.bool)
                                x
                            )
                    )
                    args
                )

        error =
            Maybe.withDefault False
                (Maybe.andThen
                    (\x ->
                        Result.toMaybe
                            (Json.Decode.decodeValue
                                (Json.Decode.at [ "error" ] Json.Decode.bool)
                                x
                            )
                    )
                    args
                )

        ( model, cmds ) =
            changeRouteTo (Navigation.fromUrl url session)
                { page = Redirect session
                , route = Nothing
                , navState = NavBar.init session
                , sideBarState = SideBar.init
                , windowHeight = height
                , url = url
                , locationUpdates = Dict.fromList []
                , allowReroute = True
                , loading = loading
                , error = error
                }
    in
    ( model
    , Cmd.batch
        [ Task.perform UpdatedTimeZone Time.here
        ]
    )



---- UPDATE ----


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url.Url
    | ReceivedCreds (Maybe Session.Cred)
    | UpdatedTimeZone Time.Zone
    | WindowResized Int Int
      ------------
      -- | UpdatedSessionCred (Maybe Session.Cred)
      ------------
    | GotNavBarMsg NavBar.Msg
    | GotSideBarMsg SideBar.Msg
      ------------
    | GotHouseholdListMsg HouseholdList.Msg
    | GotHomeMsg ()
    | GotLoginMsg Login.Msg
    | GotSettingsMsg Settings.Msg
    | GotActivateMsg Activate.Msg
    | GotLogoutMsg ()
    | GotSignupMsg Signup.Msg
      ------------
    | GotRoutesListMsg RoutesList.Msg
    | GotCreateRouteMsg CreateRoute.Msg
      ------------
    | GotBusesListMsg BusesList.Msg
    | GotBusDetailsPageMsg BusDetailsPage.Msg
    | GotBusRegistrationMsg BusRegistration.Msg
    | GotCreateBusRepairMsg CreateBusRepair.Msg
    | GotCreateFuelReportMsg CreateFuelReport.Msg
      ------------
    | GotStudentRegistrationMsg StudentRegistration.Msg
      -- | GotDashboardMsg Dashboard.Msg
      -- | GotDevicesListMsg DevicesList.Msg
    | GotDeviceRegistrationMsg DeviceRegistration.Msg
      ------------
    | GotCrewMembersMsg CrewMembers.Msg
    | GotCrewMemberRegistrationMsg CrewMemberRegistration.Msg
      ------------
    | BusMoved LocationUpdate


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        WindowResized _ height ->
            ( { model | windowHeight = height }, Cmd.none )

        GotSideBarMsg sideBarMsg ->
            let
                ( newSideBarState, newSideBarMsg ) =
                    SideBar.update sideBarMsg model.sideBarState
            in
            ( { model | sideBarState = newSideBarState }
            , Cmd.map GotSideBarMsg newSideBarMsg
            )

        GotNavBarMsg navBarMsg ->
            let
                ( newNavState, navMsg ) =
                    NavBar.update navBarMsg model.navState
            in
            ( { model | navState = newNavState }
            , Cmd.batch
                [ Cmd.map GotNavBarMsg navMsg
                , if NavBar.isVisible model.navState then
                    Cmd.map GotNavBarMsg NavBar.hideNavBarMsg

                  else
                    Cmd.none
                ]
            )

        UpdatedTimeZone timezone ->
            let
                session =
                    Session.withTimeZone (toSession model.page) timezone
            in
            changeRouteWithUpdatedSessionTo (Navigation.fromUrl model.url session) model session

        -- ( { model | windowHeight = height }, Cmd.none )
        UrlRequested urlRequest ->
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
            let
                isSamePage =
                    Navigation.isSamePage model.url url
            in
            if not isSamePage then
                changeRouteTo (Navigation.fromUrl url (toSession model.page))
                    { model | url = url }

            else
                ( model, Cmd.none )

        ReceivedCreds cred ->
            let
                session =
                    Session.withCredentials (toSession model.page) cred
            in
            if cred == Nothing then
                changeRouteWithUpdatedSessionTo (Just (Navigation.Login Nothing)) model session

            else
                changeRouteWithUpdatedSessionTo (Navigation.fromUrl model.url session) model session

        BusMoved locUpdate ->
            let
                newModel =
                    { model | locationUpdates = Dict.insert locUpdate.bus locUpdate model.locationUpdates }
            in
            updatePage msg newModel

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
        ( BusMoved _, BusesList model ) ->
            BusesList.update (BusesList.locationUpdateMsg fullModel.locationUpdates) model
                |> mapModelAndMsg BusesList GotBusesListMsg

        ( BusMoved _, BusDetailsPage model ) ->
            case Dict.get model.busID fullModel.locationUpdates of
                Just locationUpdate ->
                    BusDetailsPage.update (BusDetailsPage.locationUpdateMsg locationUpdate) model
                        |> mapModelAndMsg BusDetailsPage GotBusDetailsPageMsg

                Nothing ->
                    ( fullModel, Cmd.none )

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

        ( GotCreateBusRepairMsg msg, CreateBusRepair model ) ->
            CreateBusRepair.update msg model
                |> mapModelAndMsg CreateBusRepair GotCreateBusRepairMsg

        ( GotCreateFuelReportMsg msg, CreateFuelReport model ) ->
            CreateFuelReport.update msg model
                |> mapModelAndMsg CreateFuelReport GotCreateFuelReportMsg

        ( GotStudentRegistrationMsg msg, StudentRegistration model ) ->
            StudentRegistration.update msg model
                |> mapModelAndMsg StudentRegistration GotStudentRegistrationMsg

        -- ( GotDevicesListMsg msg, DevicesList model ) ->
        --     DevicesList.update msg model
        --         |> mapModelAndMsg DevicesList GotDevicesListMsg
        ( GotActivateMsg msg, Activate model ) ->
            Activate.update msg model
                |> mapModelAndMsg Activate GotActivateMsg

        ( GotLoginMsg msg, Login model ) ->
            Login.update msg model
                |> mapModelAndMsg Login GotLoginMsg

        ( GotSettingsMsg msg, Settings model ) ->
            Settings.update msg model
                |> mapModelAndMsg Settings GotSettingsMsg

        ( GotSignupMsg msg, Signup model ) ->
            Signup.update msg model
                |> mapModelAndMsg Signup GotSignupMsg

        ( GotDeviceRegistrationMsg msg, DeviceRegistration model ) ->
            DeviceRegistration.update msg model
                |> mapModelAndMsg DeviceRegistration GotDeviceRegistrationMsg

        ( GotRoutesListMsg msg, RoutesList model ) ->
            RoutesList.update msg model
                |> mapModelAndMsg RoutesList GotRoutesListMsg

        ( GotCreateRouteMsg msg, CreateRoute model ) ->
            CreateRoute.update msg model
                |> mapModelAndMsg CreateRoute GotCreateRouteMsg

        ( GotCrewMembersMsg msg, CrewMembers model ) ->
            CrewMembers.update msg model
                |> mapModelAndMsg CrewMembers GotCrewMembersMsg

        ( GotCrewMemberRegistrationMsg msg, CrewMemberRegistration model ) ->
            CrewMemberRegistration.update msg model
                |> mapModelAndMsg CrewMemberRegistration GotCrewMemberRegistrationMsg

        ( _, _ ) ->
            ( fullModel, Cmd.none )


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

                Just Navigation.Home ->
                    Home.init session
                        |> updateWith Home GotHomeMsg

                Just Navigation.Buses ->
                    BusesList.init session model.locationUpdates
                        |> updateWith BusesList GotBusesListMsg

                Just Navigation.BusRegistration ->
                    BusRegistration.init session
                        |> updateWith BusRegistration GotBusRegistrationMsg

                Just (Navigation.EditBusDetails busID) ->
                    BusRegistration.initEdit busID session
                        |> updateWith BusRegistration GotBusRegistrationMsg

                Just (Navigation.BusDeviceRegistration busID) ->
                    DeviceRegistration.init session busID
                        |> updateWith DeviceRegistration GotDeviceRegistrationMsg

                Just (Navigation.Bus busID preferredPage) ->
                    BusDetailsPage.init busID session (Dict.get busID model.locationUpdates) preferredPage
                        |> updateWith BusDetailsPage GotBusDetailsPageMsg

                Just (Navigation.CreateBusRepair busID) ->
                    CreateBusRepair.init busID session
                        |> updateWith CreateBusRepair GotCreateBusRepairMsg

                Just (Navigation.CreateFuelReport busID) ->
                    CreateFuelReport.init busID session
                        |> updateWith CreateFuelReport GotCreateFuelReportMsg

                Just Navigation.HouseholdList ->
                    HouseholdList.init session
                        |> updateWith HouseholdList GotHouseholdListMsg

                Just Navigation.StudentRegistration ->
                    StudentRegistration.init session Nothing
                        |> updateWith StudentRegistration GotStudentRegistrationMsg

                Just (Navigation.EditHousehold guardianId) ->
                    StudentRegistration.init session (Just guardianId)
                        |> updateWith StudentRegistration GotStudentRegistrationMsg

                Just (Navigation.Activate token) ->
                    Activate.init session token
                        |> updateWith Activate GotActivateMsg

                Just (Navigation.Login redirect) ->
                    Login.init session redirect
                        |> updateWith Login GotLoginMsg

                Just Navigation.Logout ->
                    Logout.init session
                        |> updateWith Logout GotLogoutMsg

                Just Navigation.Settings ->
                    Settings.init session
                        |> updateWith Settings GotSettingsMsg

                Just Navigation.Signup ->
                    Signup.init session
                        |> updateWith Signup GotSignupMsg

                Just Navigation.Routes ->
                    RoutesList.init session
                        |> updateWith RoutesList GotRoutesListMsg

                Just Navigation.CreateRoute ->
                    CreateRoute.init session Nothing
                        |> updateWith CreateRoute GotCreateRouteMsg

                Just (Navigation.EditRoute id) ->
                    CreateRoute.init session (Just id)
                        |> updateWith CreateRoute GotCreateRouteMsg

                Just Navigation.CrewMembers ->
                    CrewMembers.init session
                        |> updateWith CrewMembers GotCrewMembersMsg

                Just Navigation.CrewMemberRegistration ->
                    CrewMemberRegistration.init session Nothing
                        |> updateWith CrewMemberRegistration GotCrewMemberRegistrationMsg

                Just (Navigation.EditCrewMember id) ->
                    CrewMemberRegistration.init session (Just id)
                        |> updateWith CrewMemberRegistration GotCrewMemberRegistrationMsg
    in
    ( { model | page = updatedPage, route = maybeRoute }, Cmd.batch [ msg, Ports.cleanMap () ] )



---- VIEW ----


view : Model -> Browser.Document Msg
view appModel =
    let
        { page, route, navState, windowHeight, sideBarState } =
            appModel

        viewEmptyPage pageContents =
            viewPage pageContents GotHomeMsg []

        viewPage pageContents toMsg tabBarItems =
            Page.frame route pageContents (toSession page) toMsg navState GotNavBarMsg sideBarState GotSideBarMsg windowHeight tabBarItems

        -- viewEmptyPage =
        renderedView =
            let
                viewHeight =
                    Page.viewHeight windowHeight
            in
            case page of
                Home _ ->
                    viewEmptyPage Home.view

                Activate model ->
                    viewPage (Activate.view model) GotActivateMsg []

                Login model ->
                    viewPage (Login.view model) GotLoginMsg []

                Settings model ->
                    viewPage (Settings.view model) GotSettingsMsg (Settings.tabBarItems model)

                Signup model ->
                    viewPage (Signup.view model) GotSignupMsg []

                Redirect _ ->
                    viewEmptyPage Pages.Blank.view

                Logout _ ->
                    viewEmptyPage Pages.Blank.view

                NotFound _ ->
                    viewEmptyPage NotFound.view

                HouseholdList model ->
                    viewPage (HouseholdList.view model (viewHeight - TabBar.maxHeight)) GotHouseholdListMsg HouseholdList.tabBarItems

                StudentRegistration model ->
                    viewPage (StudentRegistration.view model (viewHeight - TabBar.maxHeight)) GotStudentRegistrationMsg (StudentRegistration.tabBarItems model)

                BusesList model ->
                    viewPage (BusesList.view model (viewHeight - TabBar.maxHeight)) GotBusesListMsg BusesList.tabBarItems

                BusRegistration model ->
                    viewPage (BusRegistration.view model (viewHeight - TabBar.maxHeight)) GotBusRegistrationMsg (BusRegistration.tabBarItems model)

                BusDetailsPage model ->
                    viewPage (BusDetailsPage.view model (viewHeight - TabBar.maxHeight)) GotBusDetailsPageMsg (BusDetailsPage.tabBarItems model)

                CreateBusRepair model ->
                    viewPage (CreateBusRepair.view model viewHeight) GotCreateBusRepairMsg []

                CreateFuelReport model ->
                    viewPage (CreateFuelReport.view model viewHeight) GotCreateFuelReportMsg []

                DeviceRegistration model ->
                    viewPage (DeviceRegistration.view model) GotDeviceRegistrationMsg []

                RoutesList model ->
                    viewPage (RoutesList.view model (viewHeight - TabBar.maxHeight)) GotRoutesListMsg RoutesList.tabBarItems

                CreateRoute model ->
                    viewPage (CreateRoute.view model viewHeight) GotCreateRouteMsg (CreateRoute.tabBarItems model)

                CrewMembers model ->
                    viewPage (CrewMembers.view model (viewHeight - TabBar.maxHeight)) GotCrewMembersMsg (CrewMembers.tabBarItems model)

                CrewMemberRegistration model ->
                    viewPage (CrewMemberRegistration.view model) GotCrewMemberRegistrationMsg (CrewMemberRegistration.tabBarItems model)

        layoutOptions =
            { options =
                [ focusStyle
                    { borderColor = Nothing
                    , backgroundColor = Nothing
                    , shadow = Nothing
                    }
                ]
            }
    in
    { title = "Uchukuzi"
    , body =
        [ Element.layoutWith layoutOptions
            Style.labelStyle
            (if appModel.loading then
                LoadingPage.view

             else if appModel.error then
                ErrorPage.view

             else
                renderedView
            )
        ]
    }


toSession : PageModel -> Session
toSession pageModel =
    case pageModel of
        Home model ->
            model.session

        Settings model ->
            model.session

        Logout model ->
            model.session

        Activate subModel ->
            subModel.session

        Login subModel ->
            subModel.session

        Signup subModel ->
            subModel.session

        Redirect session ->
            session

        NotFound session ->
            session

        -- Dashboard subModel ->
        --     subModel.session
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

        DeviceRegistration subModel ->
            subModel.session

        RoutesList subModel ->
            subModel.session

        CreateRoute subModel ->
            subModel.session

        CrewMembers subModel ->
            subModel.session

        CrewMemberRegistration subModel ->
            subModel.session

        CreateBusRepair subModel ->
            subModel.session

        CreateFuelReport subModel ->
            subModel.session



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model_ =
    let
        matching =
            case model_.page of
                DeviceRegistration model ->
                    Sub.map GotDeviceRegistrationMsg (DeviceRegistration.subscriptions model)

                Signup model ->
                    Sub.map GotSignupMsg (Signup.subscriptions model)

                BusesList model ->
                    Sub.map GotBusesListMsg (BusesList.subscriptions model)

                BusDetailsPage model ->
                    Sub.map GotBusDetailsPageMsg (BusDetailsPage.subscriptions model)

                StudentRegistration model ->
                    Sub.map GotStudentRegistrationMsg (StudentRegistration.subscriptions model)

                CreateRoute model ->
                    Sub.map GotCreateRouteMsg (CreateRoute.subscriptions model)

                _ ->
                    Sub.none
    in
    Sub.batch
        [ matching
        , Api.onStoreChange (Api.parseCreds >> ReceivedCreds)
        , Browser.Events.onResize WindowResized
        , Ports.onBusMove BusMoved
        , Sub.map GotSideBarMsg (SideBar.subscriptions model_.sideBarState)
        ]


main : Program (Maybe Value) Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequested
        }
