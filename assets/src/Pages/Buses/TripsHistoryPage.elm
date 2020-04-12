module Pages.Buses.TripsHistoryPage exposing (Model, Msg, init, update, view, viewFooter)

import Api exposing (get)
import Api.Endpoint as Endpoint exposing (trips)
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Errors
import Html.Attributes exposing (class, id)
import Http
import Icons
import Iso8601
import Json.Decode as Decode exposing (Decoder, float, int, list, string)
import Json.Decode.Pipeline exposing (optional, required, resolve)
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import Time
import Utils.Date


type alias Model =
    { sliderValue : Int
    , showGeofence : Bool
    , showStops : Bool
    , trips : WebData (List Trip)
    , groupedTrips : GroupedTrips
    , selectedTrip : Maybe Trip
    , timezone : Time.Zone
    }


type alias GroupedTrips =
    List ( String, List Trip )


type alias Trip =
    { startTime : Time.Posix
    , endTime : Time.Posix
    , route : String
    , points : List Location
    , length : Int
    }


type alias Location =
    { longitude : Float
    , latitude : Float
    , time : Time.Posix
    }


type Msg
    = AdjustedValue Int
    | ToggledShowGeofence Bool
    | ToggledShowStops Bool
    | TripsResponse (WebData (List Trip))
    | ClickedOn Trip


init : Session -> { bus | id : Int } -> ( Model, Cmd Msg )
init session bus =
    ( Model 0 True True RemoteData.Loading [] Nothing (Session.timeZone session)
    , Cmd.batch [ fetchTripsForBus session bus.id, Ports.initializeMaps False ]
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AdjustedValue sliderValue ->
            let
                currentPoint =
                    case model.selectedTrip of
                        Nothing ->
                            Nothing

                        Just trip ->
                            pointAt sliderValue trip
            in
            case currentPoint of
                Nothing ->
                    ( { model | sliderValue = sliderValue }, Ports.deselectPoint () )

                Just point ->
                    ( { model | sliderValue = sliderValue }, Ports.selectPoint (toGPS point) )

        ToggledShowGeofence show ->
            ( { model | showGeofence = show }, Cmd.none )

        ToggledShowStops show ->
            ( { model | showStops = show }, Cmd.none )

        TripsResponse response ->
            let
                groupedTrips =
                    case response of
                        Success trips ->
                            groupTrips trips model.timezone

                        _ ->
                            []

                command =
                    case response of
                        Success _ ->
                            Ports.initializeMaps False

                        Failure error ->
                            Tuple.second (Errors.decodeErrors error)

                        _ ->
                            Cmd.none
            in
            ( { model | trips = response, groupedTrips = groupedTrips }
            , command
            )

        ClickedOn trip ->
            if Just trip == model.selectedTrip then
                -- clicked on selected trip
                ( { model | selectedTrip = Nothing, sliderValue = 0 }, Ports.deselectPoint () )

            else
                case List.head trip.points of
                    Just firstReport ->
                        ( { model | selectedTrip = Just trip, sliderValue = 0 }, Ports.selectPoint (toGPS firstReport) )

                    Nothing ->
                        ( { model | selectedTrip = Just trip, sliderValue = 0 }, Ports.deselectPoint () )



-- VIEW


view : Model -> Element Msg
view model =
    -- Element.column
    --     [ width fill, spacing 40, paddingXY 24 8 ]
    --     [ viewHeading
    viewBody model



-- ]


viewBody : Model -> Element Msg
viewBody model =
    case model.trips of
        NotAsked ->
            text "Not fetching"

        Loading ->
            el [ width fill, height fill ] (Icons.loading [ centerX, centerY ])

        --         text "Loading..."
        Success _ ->
            Element.column
                [ width fill, spacing 26, paddingEach { edges | bottom = 40 } ]
                [ viewMapRegion model model.groupedTrips
                ]

        Failure error ->
            let
                ( apiError, _ ) =
                    Errors.decodeErrors error
            in
            text (Errors.errorToString apiError)


viewMapRegion : Model -> GroupedTrips -> Element Msg
viewMapRegion model groupedTrips =
    column [ width fill, spacing 30 ]
        [ viewMap model model.timezone
        , viewMapOptions model
        , viewTrips model.selectedTrip groupedTrips model.timezone
        ]


viewMap : Model -> Time.Zone -> Element Msg
viewMap model zone =
    let
        slider =
            case model.selectedTrip of
                Just trip ->
                    viewSlider model zone trip

                Nothing ->
                    none

        mapClasses =
            if model.selectedTrip == Nothing then
                []

            else
                [ htmlAttribute (class "selected") ]
    in
    el
        [ height (px 400)
        , width fill
        , Border.shadow { offset = ( 0, 12 ), size = 0, blur = 32, color = rgba 0 0 0 0.14 }
        , Style.clipStyle

        -- , Background.color Colors.purple
        , Border.rounded 15
        , Border.solid
        , Border.color (rgb255 197 197 197)
        , Border.width 1
        , clip
        , Background.color (rgba 0 0 0 0.05)
        , Element.inFront slider
        ]
        (StyledElement.googleMap mapClasses)


viewSlider : Model -> Time.Zone -> Trip -> Element Msg
viewSlider model zone trip =
    let
        max : Int
        max =
            List.length trip.points - 1

        currentPointTimeElement : Element msg
        currentPointTimeElement =
            let
                routeStyle =
                    Style.defaultFontFace
                        ++ [ Font.color (rgb255 85 88 98)
                           , Font.size 14
                           , Font.bold
                           ]
            in
            case pointAt model.sliderValue trip of
                Nothing ->
                    none

                Just point ->
                    el (centerX :: routeStyle) (text (String.toUpper (Utils.Date.timeFormatter zone point.time)))

        ticks : Element msg
        ticks =
            let
                createTick point =
                    el
                        [ width (px 2)
                        , height (px 8)
                        , centerY
                        , Border.rounded 1
                        , if List.head trip.points == Just point then
                            Background.color (rgba 1 1 1 0)

                          else
                            Background.color Colors.purple
                        ]
                        none
            in
            row [ spaceEvenly, width fill, centerY ] (List.map createTick trip.points)
    in
    row
        [ Style.blurredStyle
        , paddingXY 10 0
        , alignBottom
        , height (px 93)
        , Background.color (rgba 1 1 1 0.45)
        , width fill
        , Border.shadow { offset = ( 0, -6 ), size = 0, blur = 32, color = rgba 0 0 0 0.14 }
        ]
        [ -- row [] [ viewSlider model zone trip,
          el [ width (fillPortion 1), width (fillPortion 1) ] none
        , column [ width (fillPortion 40) ]
            [ Input.slider
                [ height (px 48)
                , Element.below (el (Style.captionLabelStyle ++ [ alignLeft ]) (text (Utils.Date.timeFormatter zone trip.startTime)))
                , Element.below (el (Style.captionLabelStyle ++ [ alignRight ]) (text (Utils.Date.timeFormatter zone trip.endTime)))

                -- "Track styling"
                , Element.behindContent
                    (row [ height fill, width fill, centerY, Element.behindContent ticks ]
                        [ Element.el
                            -- "Filled track"
                            [ width (fillPortion model.sliderValue)
                            , height (px 3)
                            , Background.color Colors.purple
                            , Border.rounded 2
                            ]
                            Element.none
                        , Element.el
                            -- "Default track"
                            [ width (fillPortion (max - model.sliderValue))
                            , height (px 3)
                            , alpha 0.38
                            , Background.color Colors.purple
                            , Border.rounded 2
                            ]
                            Element.none
                        ]
                    )
                ]
                { onChange = round >> AdjustedValue
                , label =
                    Input.labelHidden "Timeline Slider"
                , min = 0
                , max = Basics.toFloat max
                , step = Just 1
                , value = Basics.toFloat model.sliderValue
                , thumb =
                    Input.thumb
                        [ Background.color Colors.purple
                        , width (px 16)
                        , height (px 16)
                        , Border.rounded 8
                        , Border.solid
                        , Border.color (rgb 1 1 1)
                        , Border.width 2
                        ]
                }
            , currentPointTimeElement
            ]
        , el [ width (fillPortion 1) ] none
        ]


viewMapOptions : Model -> Element Msg
viewMapOptions model =
    row [ paddingXY 30 0, spacing 110 ]
        [--     Input.checkbox []
         --     { onChange = ToggledShowGeofence
         --     , icon = StyledElement.checkboxIcon
         --     , checked = model.showGeofence
         --     , label =
         --         Input.labelRight Style.labelStyle
         --             (text "Show Geofence")
         --     }
         -- , Input.checkbox []
         --     { onChange = ToggledShowStops
         --     , icon = StyledElement.checkboxIcon
         --     , checked = model.showStops
         --     , label =
         --         Input.labelRight Style.labelStyle
         --             (text "Show Stops")
         --     }
        ]


viewTrips : Maybe Trip -> GroupedTrips -> Time.Zone -> Element Msg
viewTrips selectedTrip groupedTrips timezone =
    column [ spacing 30 ] (List.map (viewGroupedTrips selectedTrip timezone) groupedTrips)


viewGroupedTrips : Maybe Trip -> Time.Zone -> ( String, List Trip ) -> Element Msg
viewGroupedTrips selectedTrip timezone ( month, trips ) =
    column [ spacing 8 ]
        [ el (Font.size 20 :: Font.bold :: Style.defaultFontFace) (text month)
        , wrappedRow [ spacing 12 ] (List.map (viewTrip selectedTrip timezone) trips)
        ]


viewTrip : Maybe Trip -> Time.Zone -> Trip -> Element Msg
viewTrip selectedTrip timezone trip =
    let
        timeStyle =
            Style.defaultFontFace
                ++ [ Font.color (rgb255 119 122 129)
                   , Font.size 13
                   ]

        routeStyle =
            Style.defaultFontFace
                ++ [ Font.color (rgb255 85 88 98)
                   , Font.size 14

                   --    , Font.bold
                   ]

        selectionStyles =
            if Just trip == selectedTrip then
                [ Border.color (rgb255 97 165 145)
                , moveUp 2
                , Border.shadow { offset = ( 0, 12 ), blur = 20, size = 0, color = rgba255 97 165 145 0.3 }
                ]

            else
                [ Border.color (rgba255 197 197 197 0.5)

                -- , Border.shadow { offset = ( 0, 2 ), size = 0, blur = 12, color = rgba 0 0 0 0.14 }
                ]
    in
    row
        ([ height (px 64)
         , width (fillPortion 1 |> minimum 200)
         , spacing 8
         , paddingXY 12 11
         , Background.color (rgb 1 1 1)
         , Border.solid
         , Border.width 1
         , Events.onClick (ClickedOn trip)
         , Style.animatesShadow
         ]
            ++ selectionStyles
        )
        [ column [ spacing 8 ]
            [ el (alignRight :: timeStyle ++ [ Font.color Colors.darkText ]) (text (String.toUpper (Utils.Date.timeFormatter timezone trip.startTime)))
            , el (alignRight :: timeStyle) (text (String.toUpper (Utils.Date.timeFormatter timezone trip.endTime)))

            -- , el routeStyle (text trip.route)
            ]
        , el [ width (px 3), height fill, Background.color Colors.darkGreen ] none
        , column [ spacing 8 ]
            [ el routeStyle (text trip.route)

            --  el (alignRight :: timeStyle) (text (Utils.Date.timeFormatter timezone trip.startTime))
            -- , el (alignRight :: timeStyle) (text (Utils.Date.timeFormatter timezone trip.endTime))
            -- , el routeStyle (text trip.route)
            ]
        ]


viewFooter : Model -> Element Msg
viewFooter model =
    column
        [ height fill
        , width fill

        -- , paddingXY 0 10
        ]
        [ el [ width fill, height (px 2), Background.color Colors.semiDarkText ] none
        ]



-- HTTP


fetchTripsForBus : Session -> Int -> Cmd Msg
fetchTripsForBus session bus_id =
    let
        params =
            { bus_id = bus_id }
    in
    Api.get session (Endpoint.trips params) (list tripDecoder)
        |> Cmd.map TripsResponse


tripDecoder : Decoder Trip
tripDecoder =
    let
        toDecoder : String -> String -> String -> List Location -> Int -> Decoder Trip
        toDecoder startDateString endDateString route points length =
            case ( Iso8601.toTime startDateString, Iso8601.toTime endDateString ) of
                ( Result.Ok startDate, Result.Ok endDate ) ->
                    Decode.succeed
                        { startTime = startDate
                        , endTime = endDate
                        , route = route
                        , points = points
                        , length = length
                        }

                ( Result.Err _, _ ) ->
                    Decode.fail (startDateString ++ " cannot be decoded to a date")

                ( _, Result.Err _ ) ->
                    Decode.fail (endDateString ++ " cannot be decoded to a date")
    in
    Decode.succeed toDecoder
        |> required "startTime" string
        |> required "endTime" string
        |> required "route" string
        |> required "reports" (list locationDecoder)
        |> required "length" int
        |> resolve


locationDecoder : Decoder Location
locationDecoder =
    let
        toDecoder : Float -> Float -> String -> Decoder Location
        toDecoder longitude latitude dateString =
            case Iso8601.toTime dateString of
                Result.Ok date ->
                    Decode.succeed (Location longitude latitude date)

                Result.Err _ ->
                    Decode.fail (dateString ++ " cannot be decoded to a date")
    in
    Decode.succeed toDecoder
        |> required "longitude" float
        |> required "latitude" float
        |> required "time" string
        |> resolve


groupTrips : List Trip -> Time.Zone -> GroupedTrips
groupTrips trips timezone =
    let
        tripsWithDays : List ( String, Trip )
        tripsWithDays =
            List.map (\t -> ( Utils.Date.dateFormatter timezone t.startTime, t )) trips

        orderedTrips : List ( String, Trip )
        orderedTrips =
            List.sortBy (\t -> Time.posixToMillis (Tuple.second t).startTime) tripsWithDays

        groupTripsByMonth : GroupedTrips -> List ( String, Trip ) -> GroupedTrips
        groupTripsByMonth grouped ungrouped =
            let
                remainingTrips =
                    Maybe.withDefault [] (List.tail ungrouped)
            in
            case ( List.head grouped, List.head ungrouped ) of
                -- there are no more ungrouped trips
                ( _, Nothing ) ->
                    grouped

                -- there are no grouped trips
                ( Nothing, Just ( month, trip ) ) ->
                    let
                        newGrouped =
                            [ ( month, [ trip ] ) ]
                    in
                    groupTripsByMonth newGrouped remainingTrips

                -- there are some grouped trips
                ( Just ( groupMonth, groupedTrips ), Just ( month, trip ) ) ->
                    -- there trip is for the same month as the head
                    if groupMonth == month then
                        let
                            newGrouped =
                                case List.tail grouped of
                                    Just tailOfGrouped ->
                                        ( month, trip :: groupedTrips ) :: tailOfGrouped

                                    Nothing ->
                                        [ ( month, trip :: groupedTrips ) ]
                        in
                        groupTripsByMonth newGrouped remainingTrips
                        -- there trip is for a different month the head

                    else
                        let
                            newGrouped =
                                ( month, [ trip ] ) :: grouped
                        in
                        groupTripsByMonth newGrouped remainingTrips
    in
    groupTripsByMonth [] orderedTrips


toGPS : Location -> { lat : Float, lng : Float }
toGPS location =
    { lat = location.latitude
    , lng = location.longitude
    }


pointAt : Int -> Trip -> Maybe Location
pointAt index trip =
    List.head (List.drop index trip.points)
