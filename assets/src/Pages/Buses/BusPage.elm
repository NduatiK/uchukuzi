module Pages.Buses.BusPage exposing (Model, Msg, init, locationUpdateMsg, subscriptions, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Errors
import Icons
import Json.Decode as Decode exposing (Decoder, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)
import Models.Bus exposing (Bus, LocationUpdate, Route, busDecoderWithCallback)
import Navigation
import Page
import Pages.Buses.AboutBus as About
import Pages.Buses.BusDevicePage as BusDevice
import Pages.Buses.BusRepairsPage as BusRepairs
import Pages.Buses.FuelHistoryPage as FuelHistory
import Pages.Buses.TripsHistoryPage as RouteHistory
import Ports
import RemoteData exposing (RemoteData(..), WebData)
import Session exposing (Session)
import Style
import Views.Divider exposing (viewDivider)


type alias Model =
    { session : Session
    , busData : WebData BusData
    , height : Int
    , busID : Int
    , locationUpdate : Maybe LocationUpdate
    , preferredPage : Maybe String
    }


type alias BusData =
    { bus : Bus
    , currentPage : Page
    , pages : List ( Icon, ( Page, Cmd Msg ) )
    , pageIndex : Int
    , pendingAction : Cmd Msg
    }


type alias Icon =
    List (Attribute Msg) -> Element Msg


{-| Make sure to extend the updatePage method when you add a page
-}
type Page
    = About About.Model
    | RouteHistory RouteHistory.Model
    | FuelHistory FuelHistory.Model
    | BusDevice BusDevice.Model
    | BusRepairs BusRepairs.Model


pageName page =
    case page of
        About _ ->
            "Summary"

        RouteHistory _ ->
            "Trips"

        FuelHistory _ ->
            "Fuel Log"

        BusDevice _ ->
            "Device"

        BusRepairs _ ->
            "Maintenance"


type Msg
    = GotAboutMsg About.Msg
    | GotRouteHistoryMsg RouteHistory.Msg
    | GotFuelHistoryMsg FuelHistory.Msg
    | GotBusDeviceMsg BusDevice.Msg
    | GotBusRepairsMsg BusRepairs.Msg
    | SelectedPage Int
    | ServerResponse (WebData BusData)
      ----------------
    | LocationUpdate LocationUpdate
    | MapReady Bool


locationUpdateMsg data =
    LocationUpdate data


init : Int -> Session -> Int -> Maybe LocationUpdate -> Maybe String -> ( Model, Cmd Msg )
init busID session height locationUpdate preferredPage =
    ( { session = session
      , busData = Loading
      , height = height
      , busID = busID
      , locationUpdate = locationUpdate
      , preferredPage = preferredPage
      }
    , Cmd.batch
        [ fetchBus busID session preferredPage
        , Ports.initializeLiveView ()
        ]
    )


allPagesFromSession : Bus -> Session -> Maybe String -> BusData
allPagesFromSession bus session preferredPage =
    let
        defaultPage =
            ( Icons.info, aboutPage bus session )

        pages =
            [ defaultPage
            , ( Icons.timeline, routePage bus session )
            , ( Icons.fuel, fuelPage bus session )
            , ( Icons.repairs, repairsPage bus session )
            , ( Icons.hardware, devicePage bus session )
            ]

        ( pageIndex, initialPage ) =
            case preferredPage of
                Just preferredPage_ ->
                    Maybe.withDefault
                        ( 0, defaultPage )
                        (List.head
                            (List.filter (\( index, ( _, ( page, _ ) ) ) -> String.toLower (pageName page) == String.toLower preferredPage_)
                                (List.indexedMap Tuple.pair pages)
                            )
                        )

                Nothing ->
                    ( 0, defaultPage )
    in
    { bus = bus
    , currentPage = Tuple.first (Tuple.second initialPage)
    , pendingAction = Tuple.second (Tuple.second initialPage)
    , pages = pages
    , pageIndex = List.length pages - pageIndex - 1
    }


aboutPage : Bus -> Session -> ( Page, Cmd Msg )
aboutPage bus session =
    Page.transformToModelMsg About GotAboutMsg (About.init session bus)


routePage : Bus -> Session -> ( Page, Cmd Msg )
routePage bus session =
    Page.transformToModelMsg RouteHistory GotRouteHistoryMsg (RouteHistory.init session bus)


fuelPage : Bus -> Session -> ( Page, Cmd Msg )
fuelPage bus session =
    Page.transformToModelMsg FuelHistory GotFuelHistoryMsg (FuelHistory.init bus (Session.timeZone session))


devicePage : Bus -> Session -> ( Page, Cmd Msg )
devicePage bus session =
    Page.transformToModelMsg BusDevice GotBusDeviceMsg (BusDevice.init bus session)


repairsPage : Bus -> Session -> ( Page, Cmd Msg )
repairsPage bus session =
    Page.transformToModelMsg BusRepairs GotBusRepairsMsg (BusRepairs.init bus (Session.timeZone session))



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotAboutMsg _ ->
            updatePage msg model

        GotRouteHistoryMsg _ ->
            updatePage msg model

        GotFuelHistoryMsg _ ->
            updatePage msg model

        GotBusDeviceMsg _ ->
            updatePage msg model

        GotBusRepairsMsg _ ->
            updatePage msg model

        SelectedPage selectedPage ->
            changeCurrentPage selectedPage model

        LocationUpdate locationUpdate ->
            let
                busData_ =
                    case model.busData of
                        Success busData__ ->
                            Just busData__

                        _ ->
                            Nothing
            in
            case busData_ of
                Just busData ->
                    let
                        bus =
                            busData.bus

                        ( newModel, busPageMsg ) =
                            ( { model | busData = Success { busData | bus = { bus | last_seen = Just locationUpdate } } }, Ports.updateBusMap locationUpdate )
                    in
                    case busData.currentPage of
                        About pageModel ->
                            let
                                ( newerModel, childMsg ) =
                                    About.update (About.locationUpdateMsg locationUpdate) pageModel
                                        |> mapModel newModel About GotAboutMsg
                            in
                            ( newerModel, Cmd.batch [ childMsg, busPageMsg ] )

                        _ ->
                            ( newModel, busPageMsg )

                Nothing ->
                    ( model, Ports.updateBusMap locationUpdate )

        ServerResponse response ->
            let
                next_msg =
                    case response of
                        Success busData ->
                            Cmd.batch
                                [ busData.pendingAction
                                , case ( model.locationUpdate, busData.bus.last_seen ) of
                                    ( Just locationUpdate_, _ ) ->
                                        Ports.updateBusMap locationUpdate_

                                    ( _, Just locationUpdate_ ) ->
                                        Ports.updateBusMap locationUpdate_

                                    _ ->
                                        Cmd.none
                                ]

                        Failure error ->
                            let
                                ( _, error_msg ) =
                                    Errors.decodeErrors error
                            in
                            error_msg

                        _ ->
                            Cmd.none
            in
            ( { model | busData = response }, next_msg )

        MapReady _ ->
            let
                msg_ =
                    case model.locationUpdate of
                        Just locationUpdate_ ->
                            Ports.updateBusMap locationUpdate_

                        _ ->
                            case model.busData of
                                Success busData__ ->
                                    case busData__.bus.last_seen of
                                        Just locationUpdate_ ->
                                            Ports.updateBusMap locationUpdate_

                                        _ ->
                                            Cmd.none

                                _ ->
                                    Cmd.none
            in
            ( model, msg_ )


mapModel model pageModelMapper pageMsgMapper ( subModel, subCmd ) =
    let
        modelMapper : Page -> Model
        modelMapper pageModel =
            case model.busData of
                Success busData ->
                    { model | busData = Success { busData | currentPage = pageModel } }

                _ ->
                    model
    in
    Page.transformToModelMsg (pageModelMapper >> modelMapper) pageMsgMapper ( subModel, subCmd )


updatePage : Msg -> Model -> ( Model, Cmd Msg )
updatePage msg fullModel =
    case fullModel.busData of
        Success busData ->
            case ( msg, busData.currentPage ) of
                ( GotAboutMsg msg_, About model ) ->
                    About.update msg_ model
                        |> mapModel fullModel About GotAboutMsg

                ( GotRouteHistoryMsg msg_, RouteHistory model ) ->
                    RouteHistory.update msg_ model
                        |> mapModel fullModel RouteHistory GotRouteHistoryMsg

                ( GotFuelHistoryMsg msg_, FuelHistory model ) ->
                    FuelHistory.update msg_ model
                        |> mapModel fullModel FuelHistory GotFuelHistoryMsg

                ( GotBusDeviceMsg msg_, BusDevice model ) ->
                    BusDevice.update msg_ model
                        |> mapModel fullModel BusDevice GotBusDeviceMsg

                ( GotBusRepairsMsg msg_, BusRepairs model ) ->
                    BusRepairs.update msg_ model
                        |> mapModel fullModel BusRepairs GotBusRepairsMsg

                _ ->
                    ( fullModel, Cmd.none )

        _ ->
            ( fullModel, Cmd.none )


changeCurrentPage : Int -> Model -> ( Model, Cmd Msg )
changeCurrentPage selectedPageIndex_ model_ =
    case model_.busData of
        Success busData_ ->
            let
                pages =
                    busData_.pages

                selectedPageIndex =
                    List.length pages - 1 - selectedPageIndex_

                ( selectedPage, msg ) =
                    case List.head (List.drop selectedPageIndex pages) of
                        Nothing ->
                            aboutPage busData_.bus model_.session

                        Just ( _, ( page, msg_ ) ) ->
                            ( page, msg_ )
            in
            ( { model_
                | busData =
                    Success
                        { busData_
                            | pageIndex = selectedPageIndex_
                            , currentPage = selectedPage
                        }
              }
            , Cmd.batch
                [ Navigation.replaceUrl (Session.navKey model_.session) (Navigation.Bus model_.busID (Just (pageName selectedPage)))
                , msg
                ]
            )

        _ ->
            ( model_, Cmd.none )


view : Model -> Element Msg
view model =
    case model.busData of
        Success busData ->
            viewLoaded model busData

        Failure _ ->
            el (centerX :: centerY :: Style.labelStyle) (paragraph [] [ text "Something went wrong, please reload the page" ])

        _ ->
            Icons.loading [ centerX, centerY, width (px 46), height (px 46) ]


viewLoaded : Model -> BusData -> Element Msg
viewLoaded model busData =
    let
        ( body, footer ) =
            ( viewBody model.height busData, el [ width fill, paddingEach { edges | bottom = 24 } ] (viewFooter busData) )

        edges =
            Style.edges
    in
    Element.column
        [ height fill
        , width fill
        , spacing 8

        -- , spacing 24
        , paddingXY 36 0
        ]
        [ viewHeading busData
        , Element.row
            [ width fill
            , height fill
            , spacing 26
            ]
            [ viewSidebar busData
            , body
            ]
        , el [ height (px 16) ] none
        , footer
        ]


viewHeading : BusData -> Element msg
viewHeading busData =
    Element.column
        [ width fill, paddingXY 8 8 ]
        [ paragraph (Font.color Colors.darkText :: Style.headerStyle ++ [ Font.semiBold ])
            [ el [] (text (pageName busData.currentPage))
            , text " for "
            , el
                [ Font.color Colors.semiDarkText
                , Font.semiBold
                , below
                    (el
                        [ Background.color (Colors.withAlpha Colors.semiDarkText 0.2)
                        , width fill
                        , height (px 2)
                        ]
                        none
                    )
                ]
                (text busData.bus.numberPlate)
            ]
        , case busData.bus.route of
            Nothing ->
                none

            Just route ->
                el Style.captionLabelStyle (text route.name)
        ]


viewBody : Int -> BusData -> Element Msg
viewBody height busData =
    let
        viewPage pageView toMsg =
            Element.map toMsg pageView
    in
    case busData.currentPage of
        About subPageModel ->
            viewPage (About.view subPageModel height) GotAboutMsg

        RouteHistory subPageModel ->
            viewPage (RouteHistory.view subPageModel) GotRouteHistoryMsg

        FuelHistory subPageModel ->
            viewPage (FuelHistory.view subPageModel) GotFuelHistoryMsg

        BusDevice subPageModel ->
            viewPage (BusDevice.view subPageModel) GotBusDeviceMsg

        BusRepairs subPageModel ->
            viewPage (BusRepairs.view subPageModel) GotBusRepairsMsg


viewFooter : BusData -> Element Msg
viewFooter busData =
    viewSubPageFooter busData.currentPage


viewSubPageFooter : Page -> Element Msg
viewSubPageFooter page =
    let
        viewPage pageView toMsg =
            Element.map toMsg pageView
    in
    case page of
        About subPageModel ->
            viewPage (About.viewFooter subPageModel) GotAboutMsg

        RouteHistory subPageModel ->
            viewPage (RouteHistory.viewFooter subPageModel) GotRouteHistoryMsg

        FuelHistory subPageModel ->
            viewPage (FuelHistory.viewFooter subPageModel) GotFuelHistoryMsg

        BusDevice subPageModel ->
            viewPage (BusDevice.viewFooter subPageModel) GotBusDeviceMsg

        BusRepairs subPageModel ->
            viewPage (BusRepairs.viewFooter subPageModel) GotBusRepairsMsg



-- SIDEBAR


viewSidebar : BusData -> Element Msg
viewSidebar busData =
    let
        allPages_ =
            busData.pages

        pageCount =
            List.length allPages_

        iconize index ( icon, _ ) =
            iconForPage icon index (List.length busData.pages - busData.pageIndex - 1)
    in
    el [ height fill ]
        (column
            [ Background.color (rgb255 233 233 243)
            , padding 7
            , Border.rounded 100
            , inFront (slider pageCount busData.pageIndex False)
            , behindContent (slider pageCount busData.pageIndex True)
            ]
            (List.indexedMap iconize allPages_)
        )


slider : Int -> Int -> Bool -> Element Msg
slider pageCount pageIndex visible =
    el [ paddingXY 0 7, height fill, transparent (not visible) ]
        (Input.slider
            [ height fill
            , width (px (48 + 14))
            , centerY
            ]
            { onChange = round >> SelectedPage
            , label =
                Input.labelHidden "Timeline Slider"
            , min = 0
            , max = Basics.toFloat (pageCount - 1)
            , step = Just 1
            , value = Basics.toFloat pageIndex
            , thumb =
                Input.thumb
                    [ Background.color (rgb 1 1 1)
                    , width (px 48)
                    , height (px 48)
                    , Border.rounded 48
                    , Border.solid
                    , paddingXY 0 7
                    , Border.shadow { offset = ( 0, 2 ), blur = 5, size = 0, color = rgba255 0 0 0 0.2 }
                    ]
            }
        )


iconForPage : Icon -> Int -> Int -> Element Msg
iconForPage pageIcon page currentPage =
    let
        iconFillColor =
            if page == currentPage then
                [ Colors.fillPurple
                , alpha 1
                ]

            else
                []
    in
    el [ Border.rounded 25, centerX ]
        (el
            [ padding 14
            ]
            (pageIcon
                ([ centerY
                 , centerX
                 , height (px 20)
                 , width (px 20)
                 ]
                    ++ iconFillColor
                )
            )
        )



-- NETWORK


fetchBus : Int -> Session -> Maybe String -> Cmd Msg
fetchBus busID session preferredPage =
    Api.get session (Endpoint.bus busID) (busDecoder session preferredPage)
        |> Cmd.map ServerResponse


busDecoder : Session -> Maybe String -> Decoder BusData
busDecoder session preferredPage =
    busDecoderWithCallback (\bus -> allPagesFromSession bus session preferredPage)


routeDecoder : Decoder Route
routeDecoder =
    Decode.succeed Route
        |> required "id" string
        |> required "name" string


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.mapReady MapReady
        ]
