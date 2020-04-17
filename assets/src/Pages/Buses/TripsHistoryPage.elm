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
import Icons
import Json.Decode exposing (list)
import Models.Trip exposing (Report, StudentActivity, Trip, tripDecoder)
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import Time
import Utils.DateFormatter
import Utils.GroupByDate


type alias Model =
    { sliderValue : Int
    , showGeofence : Bool
    , showStops : Bool
    , trips : WebData (List Trip)
    , groupedTrips : List GroupedTrips
    , selectedGroup : Maybe GroupedTrips
    , selectedTrip : Maybe Trip
    , timezone : Time.Zone
    }


type alias GroupedTrips =
    ( String, List Trip )


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
    | SelectedGroup GroupedTrips


init : Session -> { bus | id : Int } -> ( Model, Cmd Msg )
init session bus =
    ( { sliderValue = 0
      , showGeofence = True
      , showStops = True
      , trips = RemoteData.Loading
      , groupedTrips = []
      , selectedGroup = Nothing
      , selectedTrip = Nothing
      , timezone = Session.timeZone session
      }
    , Cmd.batch
        [ fetchTripsForBus session bus.id
        , Ports.initializeMaps False
        ]
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

                Just report ->
                    ( { model | sliderValue = sliderValue }, Ports.selectPoint report.location )

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
                case List.head trip.reports of
                    Just firstReport ->
                        ( { model | selectedTrip = Just trip, sliderValue = 0 }, Ports.selectPoint firstReport.location )

                    Nothing ->
                        ( { model | selectedTrip = Just trip, sliderValue = 0 }, Ports.deselectPoint () )

        SelectedGroup selection ->
            ( { model
                | selectedGroup = Just selection
                , sliderValue = 0
                , selectedTrip = List.head (Tuple.second selection)
              }
            , Ports.deselectPoint ()
            )



-- VIEW


view : Model -> Element Msg
view model =
    -- Element.column
    --     [ width fill, spacing 40, paddingXY 24 8 ]
    --     [ viewHeading
    --     viewBody model
    -- -- ]
    -- viewBody : Model -> Element Msg
    -- viewBody model =
    case model.trips of
        NotAsked ->
            text "Not fetching"

        Loading ->
            el [ width fill, height fill ] (Icons.loading [ centerX, centerY ])

        --         text "Loading..."
        Success _ ->
            -- Element.column
            --     [ width fill, spacing 26, paddingEach { edges | bottom = 40 } ]
            --     [
            column [ width fill, spacing 16 ]
                [ viewMap model
                , viewMapOptions model
                , viewTrips model
                ]

        -- ]
        Failure error ->
            let
                ( apiError, _ ) =
                    Errors.decodeErrors error
            in
            text (Errors.errorToString apiError)


viewMap : Model -> Element Msg
viewMap model =
    column
        [ height (px 500)

        -- [ height fill
        , width fill
        , Style.clipStyle
        , Border.solid
        , Border.color Colors.darkness
        , Border.width 1
        , clip
        , Background.color (rgba 0 0 0 0.05)
        ]
        [ row [ width fill, height fill ]
            [ StyledElement.googleMap []
            , case model.selectedTrip of
                Just trip ->
                    el
                        [ width (px 250)
                        , height fill
                        , Background.color Colors.white
                        , Border.color (Colors.withAlpha Colors.darkness 0.5)
                        , Border.widthEach { edges | left = 1 }
                        ]
                        (viewStudentActivities trip.studentActivities model.timezone)

                Nothing ->
                    none
            ]
        , case model.selectedTrip of
            Just trip ->
                viewSlider model model.timezone trip

            Nothing ->
                none
        ]


viewSlider : Model -> Time.Zone -> Trip -> Element Msg
viewSlider model zone trip =
    let
        max : Int
        max =
            List.length trip.reports - 1

        currentPointTimeElement : Element msg
        currentPointTimeElement =
            let
                routeStyle =
                    Style.defaultFontFace
                        ++ [ Font.color Colors.darkness
                           , Font.size 14
                           , Font.bold
                           ]
            in
            case pointAt model.sliderValue trip of
                Nothing ->
                    none

                Just point ->
                    el (centerX :: routeStyle) (text (String.toUpper (Utils.DateFormatter.timeFormatter zone point.time)))

        ticks : Element msg
        ticks =
            let
                createTick point =
                    el
                        [ -- width (px 2)
                          -- , height (px 8)
                          centerY
                        , if List.head trip.reports == Just point then
                            Background.color (rgba 1 1 1 0)

                          else
                            Background.color Colors.purple
                        ]
                        none
            in
            row [ spaceEvenly, width fill, centerY ] (List.map createTick trip.reports)
    in
    row
        [ paddingXY 10 0
        , Border.color Colors.darkness
        , Border.widthEach { edges | top = 1 }
        , alignBottom
        , height (px 93)
        , Background.color Colors.white
        , width fill
        ]
        [ -- row [] [ viewSlider model zone trip,
          el [ width (fillPortion 1), width (fillPortion 1) ] none
        , column [ width (fillPortion 40) ]
            [ Input.slider
                [ height (px 48)
                , Element.below (el (Style.captionLabelStyle ++ [ alignLeft ]) (text (String.toUpper (Utils.DateFormatter.timeFormatter zone trip.startTime))))
                , Element.below (el (Style.captionLabelStyle ++ [ alignRight ]) (text (String.toUpper (Utils.DateFormatter.timeFormatter zone trip.endTime))))

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


viewStudentActivities : List StudentActivity -> Time.Zone -> Element Msg
viewStudentActivities activities timezone =
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
                   ]

        selectionStyles =
            []

        viewActivity activity =
            StyledElement.plainButton [ Style.ignoreCss ]
                { onPress = Nothing
                , label =
                    row
                        ([ height (px 64)
                         , width (fillPortion 1 |> minimum 200)
                         , spacing 8
                         , paddingXY 12 11
                         , Background.color (rgb 1 1 1)

                         --  , Border.solid
                         --  , Border.width 1
                         --  , Events.onClick (ClickedOn trip)
                         , Style.animatesShadow
                         ]
                            ++ selectionStyles
                        )
                        [ column [ spacing 8 ]
                            [ el (alignRight :: timeStyle ++ [ Font.color Colors.darkText ]) (text (String.toUpper (Utils.DateFormatter.timeFormatter timezone activity.time)))

                            -- , el (alignRight :: timeStyle) (text (String.toUpper (Utils.DateFormatter.timeFormatter timezone trip.endTime)))
                            -- , el routeStyle (text trip.route)
                            ]
                        , el [ width (px 3), height fill, Background.color Colors.darkGreen ] none
                        , column [ spacing 8 ]
                            [ paragraph routeStyle [ text ("activity.studentName" ++ " " ++ String.replace "_" " " activity.activity) ]

                            --  el (alignRight :: timeStyle) (text (Utils.DateFormatter.timeFormatter timezone trip.startTime))
                            -- , el (alignRight :: timeStyle) (text (Utils.DateFormatter.timeFormatter timezone trip.endTime))
                            -- , el routeStyle (text trip.route)
                            ]
                        ]
                }
    in
    column [ width fill, height fill ] (List.map viewActivity activities)


viewMapOptions : Model -> Element Msg
viewMapOptions model =
    row [ paddingXY 10 0, spacing 110 ]
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


viewTrips : Model -> Element Msg
viewTrips { selectedGroup, selectedTrip, timezone } =
    case selectedGroup of
        Nothing ->
            el [ centerX, centerY ] (text "Select a date from below")

        Just selectedGroup_ ->
            wrappedRow [ spacing 12 ] (List.map (viewTrip selectedTrip timezone) (Tuple.second selectedGroup_))



-- viewGroupedTrips : Maybe Trip -> Time.Zone -> GroupedTrips -> Element Msg
-- viewGroupedTrips selectedTrip timezone ( month, trips ) =
--     column [ spacing 8 ]
--         [ el (Font.size 20 :: Font.bold :: Style.defaultFontFace) (text month)
--         , wrappedRow [ spacing 12 ] (List.map (viewTrip selectedTrip timezone) trips)
--         ]


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
            [ el (alignRight :: timeStyle ++ [ Font.color Colors.darkText ]) (text (String.toUpper (Utils.DateFormatter.timeFormatter timezone trip.startTime)))
            , el (alignRight :: timeStyle) (text (String.toUpper (Utils.DateFormatter.timeFormatter timezone trip.endTime)))

            -- , el routeStyle (text trip.route)
            ]
        , el [ width (px 3), height fill, Background.color Colors.darkGreen ] none
        , column [ spacing 8 ]
            [ el routeStyle (text "trip.route")

            --  el (alignRight :: timeStyle) (text (Utils.DateFormatter.timeFormatter timezone trip.startTime))
            -- , el (alignRight :: timeStyle) (text (Utils.DateFormatter.timeFormatter timezone trip.endTime))
            -- , el routeStyle (text trip.route)
            ]
        ]


viewFooter : Model -> Element Msg
viewFooter model =
    let
        viewScrollTrip group =
            Input.button [ alignTop, width fill, paddingXY 50 0 ]
                { label =
                    column
                        [ width fill, spacing 10, Style.normalScrolling ]
                        [ el
                            [ height (px 16)
                            , Style.animatesAll
                            , width (fill |> maximum 190)
                            , Background.color
                                (case model.selectedGroup of
                                    Just selectedGroup ->
                                        if Tuple.first selectedGroup == Tuple.first group then
                                            Colors.darkGreen

                                        else
                                            Colors.transparent

                                    Nothing ->
                                        Colors.transparent
                                )
                            ]
                            none
                        , el [] (text (Tuple.first group))
                        ]
                , onPress = Just (SelectedGroup group)
                }
    in
    column
        [ height fill
        , width fill
        , inFront
            (el
                [ Colors.withGradient (pi / 2) Colors.white
                , width (fill |> maximum 40)
                , height fill
                ]
                none
            )
        ]
        [ el [ width fill, height (px 2), Background.color Colors.semiDarkText ]
            none
        , row ([ width fill, scrollbarX, Style.reverseScrolling ] ++ Style.header2Style ++ [ paddingEach { edges | bottom = 16 } ])
            (List.map viewScrollTrip model.groupedTrips)
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


groupTrips : List Trip -> Time.Zone -> List GroupedTrips
groupTrips trips timezone =
    Utils.GroupByDate.group trips timezone .startTime


toGPS : Location -> { lat : Float, lng : Float }
toGPS location =
    { lat = location.latitude
    , lng = location.longitude
    }


pointAt : Int -> Trip -> Maybe Report
pointAt index trip =
    List.head (List.drop index trip.reports)
