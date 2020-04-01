module Pages.Buses.BusDetailsPage exposing (Model, Msg, init, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Icons
import Json.Decode as Decode exposing (Decoder, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)
import Models.Bus exposing (Bus)
import Page
import Pages.Buses.AboutBus as About
import Pages.Buses.BusDevicePage as BusDevice
import Pages.Buses.FuelHistoryPage as FuelHistory
import Pages.Buses.RouteHistoryPage as RouteHistory
import RemoteData exposing (RemoteData(..), WebData)
import Session exposing (Session)
import Style
import Views.Divider exposing (viewDivider)


type alias Model =
    { session : Session
    , currentPage : Page
    , pages : List ( Icon, ( Page, Cmd Msg ) )
    , pageIndex : Int
    , bus : WebData Bus
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


allPagesFromSession : Int -> Session -> List ( Icon, ( Page, Cmd Msg ) )
allPagesFromSession busID session =
    [ ( Icons.info, aboutPage busID session )
    , ( Icons.timeline, routePage busID session )
    , ( Icons.fuel, fuelPage busID session )
    , ( Icons.hardware, devicePage busID session )
    ]


aboutPage : Int -> Session -> ( Page, Cmd Msg )
aboutPage busID session =
    Page.transformToModelMsg About GotAboutMsg (About.init busID)


routePage : Int -> Session -> ( Page, Cmd Msg )
routePage busID session =
    Page.transformToModelMsg RouteHistory GotRouteHistoryMsg (RouteHistory.init session busID)


fuelPage : Int -> Session -> ( Page, Cmd Msg )
fuelPage busID session =
    Page.transformToModelMsg FuelHistory GotFuelHistoryMsg (FuelHistory.init busID (Session.timeZone session))


devicePage : Int -> Session -> ( Page, Cmd Msg )
devicePage busID session =
    Page.transformToModelMsg BusDevice GotBusDeviceMsg (BusDevice.init busID (Session.timeZone session))


type Msg
    = GotAboutMsg About.Msg
    | GotRouteHistoryMsg RouteHistory.Msg
    | GotFuelHistoryMsg FuelHistory.Msg
    | GotBusDeviceMsg BusDevice.Msg
    | SelectedPage Int
    | ServerResponse (WebData Bus)


init : Int -> Session -> ( Model, Cmd Msg )
init busID session =
    let
        allPages_ =
            allPagesFromSession busID session

        ( initialPage, initialMsg ) =
            case List.head allPages_ of
                Nothing ->
                    aboutPage busID session

                Just ( _, ( page, msg ) ) ->
                    ( page, msg )
    in
    ( Model session initialPage allPages_ (List.length allPages_ - 1) Loading
    , Cmd.batch
        [ initialMsg, fetchBus busID session ]
    )



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

        SelectedPage selectedPage ->
            changeCurrentPage selectedPage model

        ServerResponse response ->
            ( { model | bus = response }, Cmd.none )


changeCurrentPage : Int -> Model -> ( Model, Cmd Msg )
changeCurrentPage selectedPageIndex_ model_ =
    let
        allPages_ =
            model.pages

        selectedPageIndex =
            List.length allPages_ - 1 - selectedPageIndex_

        model =
            { model_ | pageIndex = selectedPageIndex_ }
    in
    case List.head (List.drop selectedPageIndex allPages_) of
        Nothing ->
            ( model, Cmd.none )

        Just ( _, ( page, msg ) ) ->
            ( { model | currentPage = page }, msg )


updatePage : Msg -> Model -> ( Model, Cmd Msg )
updatePage msg fullModel =
    let
        modelMapper : Page -> Model
        modelMapper pageModel =
            { fullModel | currentPage = pageModel }

        mapModel pageModelMapper pageMsgMapper ( subModel, subCmd ) =
            Page.transformToModelMsg (pageModelMapper >> modelMapper) pageMsgMapper ( subModel, subCmd )
    in
    case ( msg, fullModel.currentPage ) of
        ( GotAboutMsg msg_, About model ) ->
            About.update msg_ model
                |> mapModel About GotAboutMsg

        ( GotRouteHistoryMsg msg_, RouteHistory model ) ->
            RouteHistory.update msg_ model
                |> mapModel RouteHistory GotRouteHistoryMsg

        ( GotFuelHistoryMsg msg_, FuelHistory model ) ->
            FuelHistory.update msg_ model
                |> mapModel FuelHistory GotFuelHistoryMsg

        ( GotBusDeviceMsg msg_, BusDevice model ) ->
            BusDevice.update msg_ model
                |> mapModel BusDevice GotBusDeviceMsg

        _ ->
            ( fullModel, Cmd.none )


view : Model -> Element Msg
view model =
    case model.bus of
        Success bus ->
            viewLoaded model bus

        _ ->
            Icons.loading [ centerX, centerY, width (px 46), height (px 46) ]



-- _ ->


viewLoaded model bus =
    Element.row
        [ width fill
        , paddingXY 24 8
        , spacing 26
        ]
        [ viewSidebar model
        , viewBody model bus
        ]


viewHeading : Bus -> Element msg
viewHeading bus =
    Element.column
        [ width fill ]
        [ el Style.headerStyle (text bus.numberPlate)
        , el Style.captionLabelStyle (text "Ngong Road Route")
        , viewDivider
        ]


viewBody : Model -> Bus -> Element Msg
viewBody model bus =
    Element.column
        [ height fill, width fill, spacing 40 ]
        [ viewHeading bus
        , viewSubPage model.currentPage
        ]


viewSubPage : Page -> Element Msg
viewSubPage page =
    let
        viewPage pageView toMsg =
            Element.map toMsg pageView
    in
    case page of
        About subPageModel ->
            viewPage (About.view subPageModel) GotAboutMsg

        RouteHistory subPageModel ->
            viewPage (RouteHistory.view subPageModel) GotRouteHistoryMsg

        FuelHistory subPageModel ->
            viewPage (FuelHistory.view subPageModel) GotFuelHistoryMsg

        BusDevice subPageModel ->
            viewPage (BusDevice.view subPageModel) GotBusDeviceMsg


viewSidebar : Model -> Element Msg
viewSidebar model =
    let
        allPages_ =
            model.pages

        pageCount =
            List.length allPages_

        iconize ( icon, ( page, _ ) ) =
            iconForPage icon page model.currentPage
    in
    el [ paddingXY 0 300, alignTop ]
        (column
            [ Background.color (rgb255 233 233 243)
            , padding 7
            , Border.rounded 100
            , inFront (slider pageCount model.pageIndex False)
            , behindContent (slider pageCount model.pageIndex True)
            ]
            (List.map iconize allPages_)
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


iconForPage : Icon -> Page -> Page -> Element Msg
iconForPage pageIcon page currentPage =
    let
        iconFillColor =
            case ( page, currentPage ) of
                ( RouteHistory _, RouteHistory _ ) ->
                    [ Colors.fillPurple
                    , alpha 1
                    ]

                ( About _, About _ ) ->
                    [ Colors.fillPurple
                    , alpha 1
                    ]

                ( FuelHistory _, FuelHistory _ ) ->
                    [ Colors.fillPurple
                    , alpha 1
                    ]

                ( BusDevice _, BusDevice _ ) ->
                    [ Colors.fillPurple
                    , alpha 1
                    ]

                _ ->
                    [ alpha 0.54 ]
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


fetchBus : Int -> Session -> Cmd Msg
fetchBus busID session =
    Api.get session (Endpoint.bus busID) busDecoder
        |> Cmd.map ServerResponse


busDecoder : Decoder Bus
busDecoder =
    Decode.succeed Bus
        |> required "id" int
        |> required "number_plate" string
        |> required "seats_available" int
        |> required "vehicle_type" string
        |> required "stated_milage" float
