port module Main exposing (..)

-- import Json.Encode exposing (Value)

import Api
import Browser
import Browser.Events
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Element exposing (..)
import Html.Attributes
import Json.Decode as Json exposing (Value)
import Json.Decode.Pipeline exposing (optional, requiredAt)
import Json.Encode as Encode
import Layout exposing (..)
import Models.Bus exposing (LocationUpdate)
import Models.Notification exposing (Notification)
import Navigation exposing (Route)
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
import Phoenix
import Phoenix.Channel as Channel exposing (Channel)
import Phoenix.Message as PhxMsg exposing (Data, Event(..), Message(..), PhoenixCommand(..))
import Phoenix.Socket as Socket exposing (Socket)
import Ports
import Session exposing (Session)
import Style
import Task
import Template.NavBar as NavBar exposing (view)
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
    | DeviceRegistration DeviceRegistration.Model
      ------------
    | CrewMembers CrewMembers.Model
    | CrewMemberRegistration CrewMemberRegistration.Model


type alias LocalStorageData =
    { creds : Maybe Session.Cred
    , width : Int
    , height : Int
    , isLoading : Bool
    , sideBarIsOpen : Bool
    , loadError : Bool
    }


localStorageDataDecoder : Json.Decoder LocalStorageData
localStorageDataDecoder =
    Json.succeed LocalStorageData
        |> Json.Decode.Pipeline.requiredAt [ "credentials" ] (Json.nullable Api.credDecoder)
        |> Json.Decode.Pipeline.optionalAt [ "window", "width" ] Json.int 100
        |> Json.Decode.Pipeline.optionalAt [ "window", "height" ] Json.int 100
        |> Json.Decode.Pipeline.optionalAt [ "loading" ] Json.bool False
        |> Json.Decode.Pipeline.optionalAt [ "sideBarIsOpen" ] Json.bool True
        |> Json.Decode.Pipeline.optionalAt [ "error" ] Json.bool False


init : Maybe Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init args url navKey =
    let
        localStorageData =
            args
                |> Maybe.withDefault (Encode.object [])
                |> Json.decodeValue localStorageDataDecoder
                |> Result.toMaybe
                |> Maybe.withDefault (LocalStorageData Nothing 100 100 False True False)

        session =
            Session.fromCredentials navKey Time.utc localStorageData.creds

        ( phxModel, phxMsg ) =
            if localStorageData.isLoading then
                ( Nothing, Cmd.none )

            else
                localStorageData.creds
                    |> Maybe.map
                        (\credentials ->
                            let
                                phxModel_ =
                                    Phoenix.initialize
                                        (Socket.init "/socket/manager"
                                            |> Socket.withParams (Encode.object [ ( "token", Encode.string credentials.token ) ])
                                            |> Socket.onOpen (SocketOpened credentials.school_id)
                                            |> Socket.withDebug
                                        )
                                        toPhoenix
                            in
                            phxModel_
                                |> Phoenix.update (PhxMsg.createSocket phxModel_.socket)
                                |> Tuple.mapFirst Just
                        )
                    |> Maybe.withDefault ( Nothing, Cmd.none )

        ( model, cmds ) =
            changeRouteTo (Navigation.fromUrl url session)
                { page = Redirect session
                , route = Nothing
                , navState = NavBar.init
                , sideBarState = SideBar.init localStorageData.sideBarIsOpen
                , windowSize =
                    { height = localStorageData.height
                    , width = localStorageData.width
                    }
                , url = url
                , locationUpdates = Dict.fromList []
                , allowReroute = True
                , loading = localStorageData.isLoading
                , error = localStorageData.loadError
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
    | ReceivedCreds (Maybe Session.Cred)
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
    | GotBusRegistrationMsg BusRegistration.Msg
    | GotCreateBusRepairMsg CreateBusRepair.Msg
    | GotCreateFuelReportMsg CreateFuelReport.Msg
      ------------
    | GotStudentRegistrationMsg StudentRegistration.Msg
    | GotDeviceRegistrationMsg DeviceRegistration.Msg
      ------------
    | GotCrewMembersMsg CrewMembers.Msg
    | GotCrewMemberRegistrationMsg CrewMemberRegistration.Msg
      ------------
    | PhoenixMessage Event
    | SocketOpened Int
    | OutsideError String
      ------------
    | BusMoved Json.Value
    | OngoingTripUpdated Json.Value



-- | JoinedChannel Json.Value


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

                phxMsg =
                    PhxMsg.createChannel channel

                ( phoenixModel, phxCmd ) =
                    case model.phoenix of
                        Just phxModel ->
                            Phoenix.update phxMsg phxModel
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
                ( newNavState, navMsg ) =
                    NavBar.update navBarMsg model.navState (toSession model.page)
            in
            ( { model | navState = newNavState }
            , Cmd.map GotNavBarMsg navMsg
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

        ( OngoingTripUpdated tripUpdateValue, BusDetailsPage model ) ->
            BusDetailsPage.update (BusDetailsPage.ongoingTripUpdated tripUpdateValue) model
                |> mapModelAndMsg BusDetailsPage GotBusDetailsPageMsg

        ( OngoingTripUpdated tripUpdateValue, _ ) ->
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

        channel busID =
            Channel.init ("trip:" ++ String.fromInt busID)
                |> Channel.onJoin OngoingTripUpdated
                |> Channel.on "update" OngoingTripUpdated

        ( phoenixModel, phxCmd ) =
            case maybeRoute of
                Just (Navigation.Bus busID _) ->
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
                                        |> Dict.filter (\k v -> String.startsWith "trip:" k)
                                        |> Dict.values
                            in
                            List.foldl
                                (\tripChannel ( phxModel_, phxMsg_ ) ->
                                    let
                                        ( newPhxModel, newPhxMsg ) =
                                            phxModel_
                                                |> Phoenix.update (PhxMsg.leaveChannel tripChannel)
                                    in
                                    ( newPhxModel, Cmd.batch [ phxMsg_, newPhxMsg ] )
                                )
                                ( phxModel, Cmd.none )
                                tripChannels
                                |> Tuple.mapFirst Just

                        Nothing ->
                            ( model.phoenix, Cmd.none )

        -- ( model.phoenix, Cmd.none )
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
        { page, route, navState, windowSize, sideBarState, notifications } =
            appModel

        viewEmptyPage pageContents =
            viewPage pageContents GotHomeMsg []

        viewPage pageContents toMsg tabBarItems =
            Layout.frame route pageContents (toSession page) toMsg navState notifications GotNavBarMsg sideBarState GotSideBarMsg windowSize.height tabBarItems

        -- viewEmptyPage =
        renderedView =
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
                    viewPage (Activate.view model) GotActivateMsg []

                Login model ->
                    viewPage (Login.view model) GotLoginMsg []

                Settings model ->
                    viewPage (Settings.view model (viewHeight - TabBar.maxHeight)) GotSettingsMsg (Settings.tabBarItems model)

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
            (Style.labelStyle
             -- ++ [ inFront
             --         (NotificationView.view appModel.notifications)
             --    ]
            )
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

                Settings model ->
                    Sub.map GotSettingsMsg (Settings.subscriptions model)

                _ ->
                    Sub.none
    in
    Sub.batch
        [ matching
        , Api.onStoreChange (Api.parseCreds >> ReceivedCreds)
        , Browser.Events.onResize WindowResized
        , if model_.navState |> NavBar.isVisible then
            Browser.Events.onClick (Json.succeed (NavBar.hideNavBar |> GotNavBarMsg))

          else
            Sub.none
        , Sub.map GotSideBarMsg (SideBar.subscriptions model_.sideBarState)
        , PhxMsg.subscribe fromPhoenix PhoenixMessage OutsideError
        ]


port toPhoenix : Data -> Cmd msg


port fromPhoenix : (Data -> msg) -> Sub msg


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
