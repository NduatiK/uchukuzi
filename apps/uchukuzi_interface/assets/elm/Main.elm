port module Main exposing (..)


import Api
import Browser
import Browser.Events
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Element exposing (..)
import Json.Decode as Json exposing (Value)
import Json.Decode.Pipeline exposing (optionalAt)
import Json.Encode as Encode
import Layout
import Layout.NavBar as NavBar exposing (view)
import Layout.SideBar as SideBar
import Layout.TabBar as TabBar
import Models.Bus exposing (LocationUpdate)
import Models.Notification exposing (Notification)
import Navigation exposing (Route)
import Pages.Activate as Activate
import Pages.Blank
import Pages.Buses.Bus.CreateBusRepairPage as CreateBusRepair
import Pages.Buses.Bus.CreateFuelReport as CreateFuelReport
import Pages.Buses.Bus.Navigation exposing (BusPage(..))
import Pages.Buses.BusPage as BusDetailsPage
import Pages.Buses.BusesPage as BusesList
import Pages.Buses.CreateBusPage as CreateBusPage
import Pages.Crew.CrewMemberRegistrationPage as CreateCrewMemberPage
import Pages.Crew.CrewMembersPage as CrewMembers
import Pages.Devices.DeviceRegistrationPage as DeviceRegistration
import Pages.ErrorPage as ErrorPage
import Pages.Home as Home
import Pages.Households.HouseholdRegistrationPage as StudentRegistration
import Pages.Households.HouseholdsPage as HouseholdList
import Pages.LoadingPage as LoadingPage
import Pages.Login as Login
import Pages.NotFound as NotFound
import Pages.Routes.CreateRoutePage as CreateRoute
import Pages.Routes.Routes as RoutesList
import Pages.Settings as Settings
import Pages.Signup as Signup
import Phoenix
import Phoenix.Channel as Channel exposing (Channel)
import Phoenix.Message as PhxMsg exposing (Event(..), Message(..), PhoenixCommand(..), PhoenixData)
import Phoenix.Socket as Socket exposing (Socket)
import Ports
import Session exposing (Session)
import Style
import Task
import Time
import Url



---- MODEL ----


type alias Model =
    { page : PageModel
    , route : Maybe Route
    , navigationBarState : NavBar.Model
    , sideBarState : SideBar.Model
    , windowSize :
        { height : Int
        , width : Int
        }
    , url : Url.Url
    , locationUpdates : Dict Int LocationUpdate
    , allowReroute : Bool
    , loading : Bool
    , error : Bool
    , phoenix : Maybe (Phoenix.Model Msg)
    , notifications : List Notification
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
    | BusRegistration CreateBusPage.Model
    | CreateBusRepair CreateBusRepair.Model
    | CreateFuelReport CreateFuelReport.Model
      ------------
    | DeviceRegistration DeviceRegistration.Model
      ------------
    | CrewMembers CrewMembers.Model
    | CrewMemberRegistration CreateCrewMemberPage.Model


type alias LocalStorageData =
    { creds : Maybe Session.Credentials
    , window :
        { width : Int
        , height : Int
        }
    , isLoading : Bool
    , sideBarIsOpen : Bool
    , hasLoadError : Bool
    }


init : Maybe LocalStorageData -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init args url navKey =
    let
        { creds, isLoading, sideBarIsOpen, window, hasLoadError } =
            args
                |> Maybe.withDefault (LocalStorageData Nothing { width = 100, height = 100 } False True False)

        session =
            Session.fromCredentials navKey Time.utc creds

        ( phxModel, phxMsg ) =
            if isLoading then
                ( Nothing, Cmd.none )

            else
                creds
                    |> Maybe.map
                        (\credentials ->
                            initializePhoenix credentials
                        )
                    |> Maybe.withDefault ( Nothing, Cmd.none )

        ( model, _ ) =
            changeRouteTo (Navigation.fromUrl session url)
                { page = Redirect session
                , route = Nothing
                , navigationBarState = NavBar.init
                , sideBarState = SideBar.init sideBarIsOpen
                , windowSize =
                    { height = window.height
                    , width = window.width
                    }
                , url = url
                , locationUpdates = Dict.fromList []
                , allowReroute = True
                , loading = isLoading
                , error = hasLoadError
                , phoenix = phxModel
                , notifications = []
                }
    in
    ( model
    , Cmd.batch
        [ Task.perform UpdatedTimeZone Time.here
        , phxMsg
        ]
    )



---- UPDATE ----


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url.Url
    | ReceivedCreds (Maybe Session.Credentials)
    | UpdatedTimeZone Time.Zone
    | WindowResized Int Int
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
    | GotBusRegistrationMsg CreateBusPage.Msg
    | GotCreateBusRepairMsg CreateBusRepair.Msg
    | GotCreateFuelReportMsg CreateFuelReport.Msg
      ------------
    | GotStudentRegistrationMsg StudentRegistration.Msg
    | GotDeviceRegistrationMsg DeviceRegistration.Msg
      ------------
    | GotCrewMembersMsg CrewMembers.Msg
    | GotCrewMemberRegistrationMsg CreateCrewMemberPage.Msg
      ------------
    | PhoenixMessage Event
    | SocketOpened Int
    | OutsideError String
      ------------
    | ReceivedNotification Json.Value
    | BusMoved Json.Value
    | OngoingTripStarted Json.Value
    | OngoingTripUpdated Json.Value
    | OngoingTripEnded Json.Value


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PhoenixMessage incoming ->
            let
                ( phoenixModel, phxCmd ) =
                    case model.phoenix of
                        Just phxModel ->
                            Phoenix.update (Incoming incoming) phxModel
                                |> Tuple.mapFirst Just

                        Nothing ->
                            ( model.phoenix, Cmd.none )
            in
            ( { model | phoenix = phoenixModel }, phxCmd )

        SocketOpened schoolID ->
            let
                channel =
                    Channel.init ("school:" ++ String.fromInt schoolID)
                        |> Channel.on "bus_moved" BusMoved
                        |> Channel.on "notification" ReceivedNotification

                ( phoenixModel, phxCmd ) =
                    case model.phoenix of
                        Just phxModel ->
                            phxModel
                                |> Phoenix.update (PhxMsg.createChannel channel)
                                |> Tuple.mapFirst Just

                        Nothing ->
                            ( model.phoenix, Cmd.none )
            in
            ( { model | phoenix = phoenixModel }, phxCmd )

        OutsideError _ ->
            ( model, Cmd.none )

        WindowResized width height ->
            ( { model | windowSize = { height = height, width = width } }, Cmd.none )

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
                ( newNavState, navMsg, shouldClearNotifications ) =
                    NavBar.update navBarMsg model.navigationBarState (pageToSession model.page)
            in
            ( { model
                | navigationBarState = newNavState
                , notifications =
                    if shouldClearNotifications then
                        []

                    else
                        model.notifications
              }
            , Cmd.map GotNavBarMsg navMsg
            )

        UpdatedTimeZone timezone ->
            let
                session =
                    Session.withTimeZone (pageToSession model.page) timezone
            in
            changeRouteWithUpdatedSessionTo (Navigation.fromUrl session model.url) model session

        -- ( { model | windowHeight = height }, Cmd.none )
        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    case url.fragment of
                        Nothing ->
                            ( model, Cmd.none )

                        Just _ ->
                            ( model
                            , Nav.pushUrl (Session.navKey (pageToSession model.page)) (Url.toString url)
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
                changeRouteTo (Navigation.fromUrl (pageToSession model.page) url)
                    { model | url = url }

            else
                ( model, Cmd.none )

        ReceivedCreds cred ->
            let
                session =
                    Session.withCredentials (pageToSession model.page) cred
            in
            if cred == Nothing then
                changeRouteWithUpdatedSessionTo (Just (Navigation.Login Nothing)) model session
                    |> updatePhoenix

            else
                changeRouteWithUpdatedSessionTo (Navigation.fromUrl session model.url) model session
                    |> updatePhoenix

        BusMoved locUpdateValue ->
            let
                locUpdate_ =
                    locUpdateValue
                        |> Json.decodeValue Models.Bus.locationUpdateDecoder
                        |> Result.toMaybe

                newModel =
                    case locUpdate_ of
                        Just locUpdate ->
                            { model | locationUpdates = Dict.insert locUpdate.bus locUpdate model.locationUpdates }

                        Nothing ->
                            model
            in
            updatePage msg newModel

        ReceivedNotification notificationValue ->
            let
                id =
                    model.notifications
                        |> List.map .id
                        |> List.drop (List.length model.notifications - 1)
                        |> List.head
                        |> Maybe.map (\x -> x + 1)
                        |> Maybe.withDefault 1

                notification =
                    notificationValue
                        |> Json.decodeValue (Models.Notification.decoder id)
                        |> Result.toMaybe
            in
            case notification of
                Just notification_ ->
                    ( { model
                        | notifications = notification_ :: model.notifications
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        _ ->
            updatePage msg model


updatePage : Msg -> Model -> ( Model, Cmd Msg )
updatePage page_msg fullModel =
    let
        modelMapper : PageModel -> Model
        modelMapper pageModel =
            { fullModel | page = pageModel }

        mapModelAndMsg pageModelMapper pageMsgMapper ( subModel, subCmd ) =
            Layout.transformToModelMsg (pageModelMapper >> modelMapper) pageMsgMapper ( subModel, subCmd )
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

        ( OngoingTripStarted value, BusDetailsPage model ) ->
            let
                ( model_, msg_ ) =
                    BusDetailsPage.update (BusDetailsPage.ongoingTripStarted value) model
                        |> mapModelAndMsg BusDetailsPage GotBusDetailsPageMsg
            in
            ( model_, Cmd.batch [ msg_ ] )

        ( OngoingTripUpdated tripUpdateValue, BusDetailsPage model ) ->
            BusDetailsPage.update (BusDetailsPage.ongoingTripUpdated tripUpdateValue) model
                |> mapModelAndMsg BusDetailsPage GotBusDetailsPageMsg

        ( OngoingTripEnded _, BusDetailsPage model ) ->
            let
                ( model_, msg_ ) =
                    BusDetailsPage.update BusDetailsPage.ongoingTripEnded model
                        |> mapModelAndMsg BusDetailsPage GotBusDetailsPageMsg
            in
            ( model_, Cmd.batch [ msg_ ] )

        ( OngoingTripUpdated tripUpdateValue, _ ) ->
            ( fullModel, Cmd.none )

        ( GotHouseholdListMsg msg, HouseholdList model ) ->
            HouseholdList.update msg model
                |> mapModelAndMsg HouseholdList GotHouseholdListMsg

        ( GotBusesListMsg msg, BusesList model ) ->
            BusesList.update msg model
                |> mapModelAndMsg BusesList GotBusesListMsg

        ( GotBusRegistrationMsg msg, BusRegistration model ) ->
            CreateBusPage.update msg model
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
            CreateCrewMemberPage.update msg model
                |> mapModelAndMsg CrewMemberRegistration GotCrewMemberRegistrationMsg

        ( _, _ ) ->
            ( fullModel, Cmd.none )


updatePhoenix : ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
updatePhoenix ( model, msg ) =
    let
        credentials =
            model.page |> pageToSession |> Session.getCredentials
    in
    case ( credentials, model.phoenix ) of
        ( Nothing, Just phoenix ) ->
            -- Need to unsubscribe
            let
                ( phxModel, phxMsg ) =
                    phoenix
                        |> Phoenix.update PhxMsg.disconnect
                        |> Tuple.mapFirst Just
            in
            ( { model
                | phoenix = phxModel
                , notifications = []
              }
            , Cmd.batch
                [ phxMsg
                , msg
                ]
            )

        ( Just credentials_, Nothing ) ->
            -- Need to create a channel
            let
                ( phxModel, phxMsg ) =
                    initializePhoenix credentials_
            in
            ( { model | phoenix = phxModel }
            , Cmd.batch
                [ phxMsg
                , msg
                ]
            )

        _ ->
            -- No change needed
            ( model, msg )


initializePhoenix : Session.Credentials -> ( Maybe (Phoenix.Model Msg), Cmd Msg )
initializePhoenix credentials =
    let
        phxModel_ =
            Phoenix.initialize
                (Socket.init "/socket/manager"
                    |> Socket.withParams (Encode.object [ ( "token", Encode.string credentials.token ) ])
                    |> Socket.onOpen (SocketOpened credentials.school_id)
                )
                toPhoenix
    in
    phxModel_
        |> Phoenix.update (PhxMsg.createSocket phxModel_.socket)
        |> Tuple.mapFirst Just


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    let
        session =
            pageToSession model.page
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

                Just Navigation.CreateBusPage ->
                    CreateBusPage.init session
                        |> updateWith BusRegistration GotBusRegistrationMsg

                Just (Navigation.EditBusDetails busID) ->
                    CreateBusPage.initEdit busID session
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

                Just Navigation.CreateHousehold ->
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

                Just Navigation.CreateCrewMember ->
                    CreateCrewMemberPage.init session Nothing
                        |> updateWith CrewMemberRegistration GotCrewMemberRegistrationMsg

                Just (Navigation.EditCrewMember id) ->
                    CreateCrewMemberPage.init session (Just id)
                        |> updateWith CrewMemberRegistration GotCrewMemberRegistrationMsg

        channel busID =
            Channel.init ("trip:" ++ String.fromInt busID)
                |> Channel.onJoin OngoingTripUpdated
                |> Channel.on "started" OngoingTripStarted
                |> Channel.on "update" OngoingTripUpdated
                |> Channel.on "ended" OngoingTripEnded

        ( phoenixModel, phxCmd ) =
            case maybeRoute of
                Just (Navigation.Bus busID RouteHistory) ->
                    case model.phoenix of
                        Just phxModel ->
                            Phoenix.update (PhxMsg.createChannel (channel busID)) phxModel
                                |> Tuple.mapFirst Just

                        Nothing ->
                            ( model.phoenix, Cmd.none )

                _ ->
                    case model.phoenix of
                        Just phxModel ->
                            let
                                tripChannels =
                                    phxModel.channels
                                        |> Dict.filter (\k _ -> String.startsWith "trip:" k)
                                        |> Dict.values
                            in
                            tripChannels
                                |> List.foldl
                                    (\tripChannel ( phxModel_, phxMsg_ ) ->
                                        let
                                            ( newPhxModel, newPhxMsg ) =
                                                phxModel_
                                                    |> Phoenix.update (PhxMsg.leaveChannel tripChannel)
                                        in
                                        ( newPhxModel, Cmd.batch [ phxMsg_, newPhxMsg ] )
                                    )
                                    ( phxModel, Cmd.none )
                                |> Tuple.mapFirst Just

                        Nothing ->
                            ( model.phoenix, Cmd.none )
    in
    ( { model | page = updatedPage, route = maybeRoute, phoenix = phoenixModel }
    , Cmd.batch
        [ msg
        , Ports.cleanMap ()
        , phxCmd
        ]
    )



---- VIEW ----


view : Model -> Browser.Document Msg
view appModel =
    let
        { page, route, navigationBarState, windowSize, sideBarState, notifications } =
            appModel

        viewEmptyPage pageContents =
            viewPage pageContents GotHomeMsg []

        viewPage pageContents toMsg tabBarItems =
            Layout.frame (pageToSession page)
                route
                { body = pageContents
                , bodyMsgToPageMsg = toMsg
                }
                { navBarState = navigationBarState
                , notifications = notifications
                , navBarMsgToPageMsg = GotNavBarMsg
                }
                { sideBarState = sideBarState
                , sideBarMsgToPageMsg = GotSideBarMsg
                }
                windowSize.height
                tabBarItems

        renderView : () -> Element Msg
        renderView () =
            let
                viewHeight =
                    Layout.viewHeight windowSize.height

                viewWidth =
                    windowSize.width - SideBar.unwrapWidth appModel.sideBarState - Layout.sideBarOffset
            in
            case page of
                Home _ ->
                    viewEmptyPage Home.view

                Activate model ->
                    viewPage (Activate.view model viewHeight) GotActivateMsg []

                Login model ->
                    viewPage (Login.view model viewHeight) GotLoginMsg []

                Settings model ->
                    viewPage (Settings.view model (viewHeight - TabBar.maxHeight)) GotSettingsMsg (Settings.tabBarItems model)

                Signup model ->
                    viewPage (Signup.view model viewHeight) GotSignupMsg []

                Redirect _ ->
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
                    viewPage (CreateBusPage.view model (viewHeight - TabBar.maxHeight)) GotBusRegistrationMsg (CreateBusPage.tabBarItems model)

                BusDetailsPage model ->
                    viewPage (BusDetailsPage.view model (viewHeight - TabBar.maxHeight) viewWidth) GotBusDetailsPageMsg (BusDetailsPage.tabBarItems model)

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
                    viewPage (CreateCrewMemberPage.view model) GotCrewMemberRegistrationMsg (CreateCrewMemberPage.tabBarItems model)

        layoutOptions =
            { options =
                [ focusStyle
                    { borderColor = Nothing
                    , backgroundColor = Nothing
                    , shadow = Nothing

                    -- Just
                    --     { color =
                    --         Colors.purple
                    --     , offset = ( 0, 0 )
                    --     , blur = 0
                    --     , size = 3
                    --     }
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
                renderView ()
            )
        ]
    }


pageToSession : PageModel -> Session
pageToSession pageModel =
    case pageModel of
        Home model ->
            model.session

        Settings model ->
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

                Settings model ->
                    Sub.map GotSettingsMsg (Settings.subscriptions model)

                _ ->
                    Sub.none
    in
    Sub.batch
        [ matching
        , Api.credentialsChanged ReceivedCreds
        , Browser.Events.onResize WindowResized
        , if model_.navigationBarState |> NavBar.isVisible then
            Browser.Events.onClick (Json.succeed (NavBar.hideNavBar |> GotNavBarMsg))

          else
            Sub.none
        , Sub.map GotSideBarMsg (SideBar.subscriptions model_.sideBarState)
        , PhxMsg.subscribe fromPhoenix PhoenixMessage OutsideError
        ]


port toPhoenix : PhoenixData -> Cmd msg


port fromPhoenix : (PhoenixData -> msg) -> Sub msg


main : Program (Maybe LocalStorageData) Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequested
        }
