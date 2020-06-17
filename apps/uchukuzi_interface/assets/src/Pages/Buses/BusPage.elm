module Pages.Buses.BusPage exposing
    ( Model
    , Msg
    , Page(..)
    , init
    , locationUpdateMsg
    , ongoingTripEnded
    , ongoingTripStarted
    , ongoingTripUpdated
    , pageName
    , subscriptions
    , tabBarItems
    , update
    , view
    )

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Errors
import Html.Attributes exposing (id)
import Icons
import Json.Decode exposing (Decoder)
import Layout
import Layout.TabBar as TabBar exposing (TabBarItem(..))
import Models.Bus exposing (Bus, LocationUpdate, busDecoderWithCallback)
import Navigation
import Pages.Buses.Bus.AboutBus as About
import Pages.Buses.Bus.DevicePage as BusDevice
import Pages.Buses.Bus.FuelHistoryPage as FuelHistory
import Pages.Buses.Bus.Navigation exposing (BusPage(..), busPageToString)
import Pages.Buses.Bus.RepairsPage as BusRepairs
import Pages.Buses.Bus.TripsHistoryPage as RouteHistory
import Ports
import RemoteData exposing (RemoteData(..), WebData)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement.WebDataView as WebDataView


type alias Model =
    { session : Session
    , busData : WebData BusData
    , busID : Int
    , locationUpdate : Maybe LocationUpdate
    , currentPage : BusPage
    }


type alias BusData =
    { bus : Bus
    , currentPage : Page
    , pages : List ( Page, Cmd Msg )
    , pageIndex : Int
    , pendingAction : Cmd Msg
    }


{-| Make sure to extend the updatePage method when you add a page
-}
type Page
    = AboutPage About.Model
    | RouteHistoryPage RouteHistory.Model
    | FuelHistoryPage FuelHistory.Model
    | BusDevicePage BusDevice.Model
    | BusRepairsPage BusRepairs.Model


aboutPage : Bus -> Session -> Maybe LocationUpdate -> ( Page, Cmd Msg )
aboutPage bus session locationUpdate =
    Layout.transformToModelMsg AboutPage GotAboutMsg (About.init session bus locationUpdate)


routePage : Bus -> Session -> ( Page, Cmd Msg )
routePage bus session =
    Layout.transformToModelMsg RouteHistoryPage GotRouteHistoryMsg (RouteHistory.init bus.id session)


fuelPage : Bus -> Session -> ( Page, Cmd Msg )
fuelPage bus session =
    Layout.transformToModelMsg FuelHistoryPage GotFuelHistoryMsg (FuelHistory.init bus.id session)


devicePage : Bus -> Session -> ( Page, Cmd Msg )
devicePage bus session =
    Layout.transformToModelMsg BusDevicePage GotBusDeviceMsg (BusDevice.init bus session)


repairsPage : Bus -> Session -> ( Page, Cmd Msg )
repairsPage bus session =
    Layout.transformToModelMsg BusRepairsPage GotBusRepairsMsg (BusRepairs.init session bus.id bus.repairs (Session.timeZone session))


init : Int -> Session -> Maybe LocationUpdate -> BusPage -> ( Model, Cmd Msg )
init busID session locationUpdate currentPage =
    ( { session = session
      , busData = Loading
      , busID = busID
      , locationUpdate = locationUpdate
      , currentPage = currentPage
      }
    , Cmd.batch
        [ fetchBus busID session currentPage locationUpdate
        ]
    )



-- UPDATE


type Msg
    = GotAboutMsg About.Msg
    | GotRouteHistoryMsg RouteHistory.Msg
    | GotFuelHistoryMsg FuelHistory.Msg
    | GotBusDeviceMsg BusDevice.Msg
    | GotBusRepairsMsg BusRepairs.Msg
      ----------------
    | SelectedPage Int
    | ReceivedBusResponse (WebData BusData)
      ----------------
    | LocationUpdate LocationUpdate


locationUpdateMsg =
    LocationUpdate


ongoingTripUpdated : Json.Decode.Value -> Msg
ongoingTripUpdated =
    RouteHistory.ongoingTripUpdated >> GotRouteHistoryMsg


ongoingTripStarted : Json.Decode.Value -> Msg
ongoingTripStarted =
    ongoingTripUpdated


ongoingTripEnded : Msg
ongoingTripEnded =
    GotRouteHistoryMsg RouteHistory.ongoingTripEnded


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

                        newModel =
                            { model | busData = Success { busData | bus = { bus | lastSeen = Just locationUpdate } } }
                    in
                    case busData.currentPage of
                        AboutPage pageModel ->
                            let
                                ( newerModel, childMsg ) =
                                    About.update (About.locationUpdateMsg locationUpdate) pageModel
                                        |> mapModel newModel AboutPage GotAboutMsg
                            in
                            ( newerModel, childMsg )

                        _ ->
                            ( newModel, Cmd.none )

                Nothing ->
                    ( model, Ports.updateBusMap locationUpdate )

        ReceivedBusResponse response ->
            let
                next_msg =
                    case response of
                        Success busData ->
                            let
                                pages =
                                    busData.pages

                                selectedPageIndex =
                                    List.length pages - 1 - busData.pageIndex

                                ( _, pageMsg ) =
                                    case List.head (List.drop selectedPageIndex pages) of
                                        Nothing ->
                                            aboutPage busData.bus model.session model.locationUpdate

                                        Just ( page, msg_ ) ->
                                            ( page, msg_ )
                            in
                            pageMsg

                        Failure error ->
                            Errors.toMsg error

                        _ ->
                            Cmd.none
            in
            ( { model | busData = response }, next_msg )


mapModel : Model -> (subModel -> Page) -> (subCmd -> Msg) -> ( subModel, Cmd subCmd ) -> ( Model, Cmd Msg )
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
    Layout.transformToModelMsg (pageModelMapper >> modelMapper) pageMsgMapper ( subModel, subCmd )


updatePage : Msg -> Model -> ( Model, Cmd Msg )
updatePage msg fullModel =
    case fullModel.busData of
        Success busData ->
            case ( msg, busData.currentPage ) of
                ( GotAboutMsg msg_, AboutPage model ) ->
                    About.update msg_ model
                        |> mapModel fullModel AboutPage GotAboutMsg

                ( GotRouteHistoryMsg msg_, RouteHistoryPage model ) ->
                    RouteHistory.update msg_ model
                        |> mapModel fullModel RouteHistoryPage GotRouteHistoryMsg

                ( GotFuelHistoryMsg msg_, FuelHistoryPage model ) ->
                    FuelHistory.update msg_ model
                        |> mapModel fullModel FuelHistoryPage GotFuelHistoryMsg

                ( GotBusRepairsMsg msg_, BusRepairsPage model ) ->
                    BusRepairs.update msg_ model
                        |> mapModel fullModel BusRepairsPage GotBusRepairsMsg

                ( GotBusDeviceMsg msg_, BusDevicePage model ) ->
                    BusDevice.update msg_ model
                        |> mapModel fullModel BusDevicePage GotBusDeviceMsg

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
                            aboutPage busData_.bus model_.session model_.locationUpdate

                        Just ( page, msg_ ) ->
                            ( page, msg_ )
            in
            ( { model_
                | busData =
                    Success
                        { busData_
                            | pageIndex = selectedPageIndex_
                            , currentPage = selectedPage
                        }
                , currentPage = pageToBusPage selectedPage
              }
            , Cmd.batch
                [ msg
                , Navigation.replaceUrl (Session.navKey model_.session) (Navigation.Bus model_.busID (pageToBusPage selectedPage))
                , Ports.cleanMap ()
                ]
            )

        _ ->
            ( model_, Cmd.none )



-- VIEW


view : Model -> Int -> Int -> Element Msg
view model viewHeight viewWidth =
    WebDataView.view model.busData
        (\busData ->
            viewLoaded busData viewHeight viewWidth
        )


viewLoaded : BusData -> Int -> Int -> Element Msg
viewLoaded busData viewHeight viewWidth =
    let
        columnSpacing =
            8

        ( body, footer, buttons ) =
            ( viewBody (viewHeight - headerHeight - columnSpacing) viewWidth busData
            , viewFooter busData (viewWidth - 55)
            , viewButtons busData
            )
    in
    Element.column
        [ height fill
        , width fill
        , spacing columnSpacing

        -- , Background.color Colors.darkText
        , htmlAttribute (id (pageName busData.currentPage))
        , case busData.currentPage of
            FuelHistoryPage _ ->
                paddingEach { edges | left = 36 }

            AboutPage _ ->
                paddingEach { edges | left = 36 }

            _ ->
                paddingXY 36 0
        , inFront (viewOverlay busData viewHeight)
        ]
        ([ viewHeading busData buttons
         , Element.row
            [ width fill
            , height fill
            ]
            [ viewSidebar busData
            , el
                [ case busData.currentPage of
                    FuelHistoryPage _ ->
                        paddingEach { edges | left = 26 }

                    _ ->
                        paddingXY 26 0
                , width fill
                , height fill
                ]
                body
            ]
         ]
            ++ (if footer /= none then
                    [ el [ height (px 16) ] none
                    , footer
                    ]

                else
                    []
               )
        )


headerHeight =
    68


viewHeading : BusData -> Element msg -> Element msg
viewHeading busData button =
    row
        [ width fill
        , paddingEach { edges | right = 36 }
        , height (px headerHeight)
        ]
        [ Element.column
            [ width fill ]
            [ paragraph (Font.color Colors.darkText :: Style.headerStyle ++ [ Font.semiBold, paddingXY 0 12 ])
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
                    el Style.captionStyle (text route.name)
            ]
        , el [ centerY ] button
        ]


viewBody : Int -> Int -> BusData -> Element Msg
viewBody height width busData =
    let
        viewPage pageView toMsg =
            Element.map toMsg pageView
    in
    case busData.currentPage of
        AboutPage subPageModel ->
            viewPage (About.view subPageModel height) GotAboutMsg

        RouteHistoryPage subPageModel ->
            viewPage (RouteHistory.view subPageModel width) GotRouteHistoryMsg

        FuelHistoryPage subPageModel ->
            viewPage (FuelHistory.view subPageModel height) GotFuelHistoryMsg

        BusDevicePage subPageModel ->
            viewPage (BusDevice.view subPageModel) GotBusDeviceMsg

        BusRepairsPage subPageModel ->
            viewPage (BusRepairs.view subPageModel height) GotBusRepairsMsg


viewFooter : BusData -> Int -> Element Msg
viewFooter busData viewWidth =
    let
        viewPage pageView toMsg =
            Element.map toMsg pageView

        buildFooter footer =
            if footer /= none then
                el [ width fill, paddingEach { edges | bottom = 24 } ]
                    (el [ width (fill |> maximum viewWidth), height fill ] footer)

            else
                none
    in
    buildFooter
        (case busData.currentPage of
            AboutPage subPageModel ->
                viewPage (About.viewFooter subPageModel) GotAboutMsg

            RouteHistoryPage subPageModel ->
                viewPage (RouteHistory.viewFooter subPageModel) GotRouteHistoryMsg

            FuelHistoryPage subPageModel ->
                viewPage (FuelHistory.viewFooter subPageModel) GotFuelHistoryMsg

            BusDevicePage subPageModel ->
                viewPage (BusDevice.viewFooter subPageModel) GotBusDeviceMsg

            BusRepairsPage subPageModel ->
                viewPage (BusRepairs.viewFooter subPageModel) GotBusRepairsMsg
        )


viewOverlay : BusData -> Int -> Element Msg
viewOverlay busData viewHeight =
    let
        viewPage pageView toMsg =
            Element.map toMsg pageView
    in
    el [ width fill, height fill, Style.clickThrough ]
        -- el [ width (fill |> maximum viewWidth), height fill ]
        (case busData.currentPage of
            AboutPage subPageModel ->
                none

            RouteHistoryPage subPageModel ->
                viewPage (RouteHistory.viewOverlay subPageModel viewHeight) GotRouteHistoryMsg

            -- none
            FuelHistoryPage subPageModel ->
                none

            BusDevicePage subPageModel ->
                none

            BusRepairsPage subPageModel ->
                none
        )


viewButtons : BusData -> Element Msg
viewButtons busData =
    let
        viewPage pageView toMsg =
            Element.map toMsg pageView
    in
    case busData.currentPage of
        AboutPage subPageModel ->
            viewPage (About.viewButtons subPageModel) GotAboutMsg

        FuelHistoryPage subPageModel ->
            viewPage (FuelHistory.viewButtons subPageModel) GotFuelHistoryMsg

        _ ->
            none



-- SIDEBAR


viewSidebar : BusData -> Element Msg
viewSidebar busData =
    let
        allPages_ =
            busData.pages

        pageCount =
            List.length allPages_

        iconize index ( page, _ ) =
            iconForPage page index (List.length busData.pages - busData.pageIndex - 1)
    in
    el [ height fill ]
        (column
            [ Background.color (rgb255 233 233 243)

            -- , Border.innerShadow
            --     { offset = ( -4, -4 )
            --     , size = 0
            --     , blur = 16
            --     , color = Colors.withAlpha Colors.purple 0.2
            --     }
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

                    -- , Border.shadow
                    --     { offset = ( 0, 2 )
                    --     , blur = 5
                    --     , size = 0
                    --     , color = rgba255 0 0 0 0.2
                    --     }
                    , Border.shadow
                        { offset = ( 0, 0 )
                        , size = 4
                        , blur = 8
                        , color = rgb255 (255 - ((255 - 233) * 2)) (255 - ((255 - 233) * 2)) (255 - ((255 - 243) * 2))
                        }
                    ]
            }
        )


iconForPage : Page -> Int -> Int -> Element Msg
iconForPage page pageIndex currentPageIndex =
    let
        iconStyle =
            [ centerY
            , centerX
            , height (px 20)
            , width (px 20)
            , alpha 1
            ]

        icon =
            case page of
                FuelHistoryPage _ ->
                    Icons.fuel iconStyle

                AboutPage _ ->
                    Icons.info iconStyle

                RouteHistoryPage _ ->
                    Icons.timeline iconStyle

                BusDevicePage _ ->
                    Icons.hardware iconStyle

                BusRepairsPage _ ->
                    Icons.repairs iconStyle

        iconFillColor =
            if pageIndex == currentPageIndex then
                [ Colors.fillPurple
                , alpha 1
                ]

            else
                [ alpha 0.54 ]
    in
    el [ Border.rounded 25, centerX, padding 14 ]
        (el
            ([ centerY
             , centerX
             , height (px 20)
             , width (px 20)
             , alpha 1
             ]
                ++ iconFillColor
            )
            icon
        )



-- NETWORK


fetchBus : Int -> Session -> BusPage -> Maybe LocationUpdate -> Cmd Msg
fetchBus busID session currentPage locationUpdate =
    Api.get session (Endpoint.bus busID) (busDecoder session currentPage locationUpdate)
        |> Cmd.map ReceivedBusResponse


busDecoder : Session -> BusPage -> Maybe LocationUpdate -> Decoder BusData
busDecoder session currentPage locationUpdate =
    busDecoderWithCallback (\bus -> allPagesFromSession bus session locationUpdate currentPage)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        []


pageToBusPage : Page -> BusPage
pageToBusPage page =
    case page of
        AboutPage _ ->
            Pages.Buses.Bus.Navigation.About

        RouteHistoryPage _ ->
            Pages.Buses.Bus.Navigation.RouteHistory

        FuelHistoryPage _ ->
            Pages.Buses.Bus.Navigation.FuelHistory

        BusDevicePage _ ->
            Pages.Buses.Bus.Navigation.BusDevice

        BusRepairsPage _ ->
            Pages.Buses.Bus.Navigation.BusRepairs


pageName =
    pageToBusPage >> busPageToString >> String.replace "_" " "


allPagesFromSession : Bus -> Session -> Maybe LocationUpdate -> BusPage -> BusData
allPagesFromSession bus session locationUpdate currentPage =
    let
        defaultPage =
            aboutPage bus session locationUpdate

        pages =
            [ defaultPage
            , routePage bus session
            , fuelPage bus session
            , repairsPage bus session
            , devicePage bus session
            ]

        ( pageIndex, initialPage ) =
            pages
                |> List.indexedMap Tuple.pair
                |> List.filter (\( index, ( page, cmd ) ) -> pageToBusPage page == currentPage)
                |> List.head
                |> Maybe.withDefault
                    ( 0, defaultPage )
    in
    { bus = bus
    , currentPage = Tuple.first initialPage
    , pendingAction = Tuple.second initialPage
    , pages = pages
    , pageIndex = List.length pages - pageIndex - 1
    }


tabBarItems : Model -> List (TabBarItem Msg)
tabBarItems { busData } =
    case busData of
        Success busData_ ->
            case busData_.currentPage of
                AboutPage _ ->
                    About.tabBarItems GotAboutMsg

                RouteHistoryPage model ->
                    RouteHistory.tabBarItems model GotRouteHistoryMsg

                -- Pages.Buses.Bus.Navigation.RouteHistory
                FuelHistoryPage _ ->
                    FuelHistory.tabBarItems GotFuelHistoryMsg

                -- Pages.Buses.Bus.Navigation.FuelHistory
                BusDevicePage _ ->
                    []

                -- Pages.Buses.Bus.Navigation.BusDevice
                BusRepairsPage _ ->
                    BusRepairs.tabBarItems GotBusRepairsMsg

        _ ->
            []



-- Pages.Buses.Bus.Navigation.BusRepairs
