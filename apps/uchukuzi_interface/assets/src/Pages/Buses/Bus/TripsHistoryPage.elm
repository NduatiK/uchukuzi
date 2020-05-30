module Pages.Buses.Bus.TripsHistoryPage exposing (Model, Msg, init, tabBarItems, update, view, viewFooter)

import Api exposing (get)
import Api.Endpoint as Endpoint exposing (trips)
import Colors
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Errors
import Icons
import Json.Decode exposing (list)
import Models.Location exposing (Report)
import Models.Trip exposing (LightWeightTrip, StudentActivity, Trip, tripDecoder, tripDetailsDecoder)
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import Task
import Template.TabBar as TabBar
import Time
import Utils.DateFormatter
import Utils.GroupBy


type alias Model =
    { sliderValue : Int
    , showGeofence : Bool
    , showingOngoingTrip : Bool
    , showStops : Bool
    , trips : WebData (List Models.Trip.LightWeightTrip)
    , groupedTrips : List GroupedTrips
    , selectedGroup : Maybe GroupedTrips
    , selectedTrip : Maybe Trip
    , session : Session
    , loadedTrips : Dict Int Trip
    , loadingTrip : WebData Models.Trip.Trip
    , requestedTrip : Maybe Int
    }


type alias GroupedTrips =
    ( String, List LightWeightTrip )


type alias Location =
    { longitude : Float
    , latitude : Float
    , time : Time.Posix
    }


init : Int -> Session -> ( Model, Cmd Msg )
init busID session =
    ( { sliderValue = 0
      , showGeofence = True
      , showStops = True
      , trips = RemoteData.Loading
      , showingOngoingTrip = True
      , groupedTrips = []
      , selectedGroup = Nothing
      , selectedTrip = Nothing
      , session = session
      , loadedTrips = Dict.fromList []
      , loadingTrip = NotAsked
      , requestedTrip = Nothing
      }
    , Cmd.batch
        [ fetchTripsForBus session busID
        ]
    )


type Msg
    = AdjustedValue Int
    | ToggledShowGeofence Bool
    | ToggledShowStops Bool
    | ReceivedTripsResponse (WebData (List Models.Trip.LightWeightTrip))
    | ReceivedTripDetailsResponse (WebData Models.Trip.Trip)
    | ClickedOn Int
    | SelectedGroup GroupedTrips
      ------
    | ShowHistoricalTrips
    | ShowCurrentTrip



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

                scrollToStudentActivity =
                    Cmd.none

                -- Browser.Dom.getViewportOf viewRecordsID
                --     |> Task.andThen (.scene >> .height >> Browser.Dom.setViewportOf viewRecordsID 0)
                --     |> Task.onError (\_ -> Task.succeed ())
                --     |> Task.perform (\_ -> NoOp)
            in
            case currentPoint of
                Nothing ->
                    ( { model | sliderValue = sliderValue }
                    , Cmd.batch
                        [ Ports.deselectPoint ()
                        , scrollToStudentActivity
                        ]
                    )

                Just report ->
                    ( { model | sliderValue = sliderValue }
                    , Cmd.batch
                        [ Ports.selectPoint
                            { location = report.location
                            , bearing = report.bearing
                            }
                        , case model.selectedTrip of
                            Nothing ->
                                Cmd.none

                            Just trip ->
                                drawPath trip sliderValue
                        , scrollToStudentActivity
                        ]
                    )

        ToggledShowGeofence show ->
            ( { model | showGeofence = show }, Cmd.none )

        ToggledShowStops show ->
            ( { model | showStops = show }, Cmd.none )

        ReceivedTripsResponse response ->
            let
                groupedTrips =
                    case response of
                        Success trips ->
                            groupTrips trips (Session.timeZone model.session)

                        _ ->
                            []

                command =
                    case response of
                        Success _ ->
                            Ports.initializeMaps

                        Failure error ->
                            Tuple.second (Errors.decodeErrors error)

                        _ ->
                            Cmd.none
            in
            ( { model | trips = response, groupedTrips = groupedTrips }
            , command
            )

        ReceivedTripDetailsResponse response ->
            case response of
                Success trip ->
                    ( { model
                        | loadedTrips = Dict.insert trip.id trip model.loadedTrips
                        , loadingTrip = NotAsked
                      }
                    , if model.requestedTrip == Just trip.id then
                        Task.succeed (ClickedOn trip.id) |> Task.perform identity

                      else
                        Cmd.none
                    )

                _ ->
                    ( { model | loadingTrip = response }
                    , Cmd.none
                    )

        ClickedOn tripID ->
            if Just tripID == Maybe.andThen (.id >> Just) model.selectedTrip then
                -- clicked on currently selected trip
                ( { model | selectedTrip = Nothing, sliderValue = 0 }
                , Cmd.batch
                    [ Ports.deselectPoint ()
                    , Ports.cleanMap ()
                    ]
                )

            else
                case Dict.get tripID model.loadedTrips of
                    Just loadedTrip ->
                        ( { model
                            | selectedTrip = Just loadedTrip
                            , requestedTrip = Nothing
                            , sliderValue = 0
                          }
                        , Cmd.batch
                            [ case pointAt model.sliderValue loadedTrip of
                                Nothing ->
                                    Ports.deselectPoint ()

                                Just report ->
                                    Ports.selectPoint
                                        { location = report.location
                                        , bearing = report.bearing
                                        }
                            , drawPath loadedTrip 0
                            , Ports.cleanMap ()
                            ]
                        )

                    Nothing ->
                        ( { model | loadingTrip = Loading, requestedTrip = Just tripID }
                        , Cmd.batch
                            [ fetchReportsForTrip model.session tripID
                            , Ports.cleanMap ()
                            ]
                        )

        SelectedGroup selection ->
            ( { model
                | selectedGroup = Just selection
                , sliderValue = 0
              }
            , Ports.deselectPoint ()
            )

        ShowHistoricalTrips ->
            ( { model | showingOngoingTrip = False }, Ports.cleanMap () )

        ShowCurrentTrip ->
            ( { model | showingOngoingTrip = True }, Ports.cleanMap () )



-- VIEW


view : Model -> Element Msg
view model =
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
                , if not model.showingOngoingTrip then
                    viewTrips model
                    -- viewFooter has the rest

                  else
                    none
                ]

        -- ]
        Failure error ->
            let
                ( apiError, _ ) =
                    Errors.decodeErrors error
            in
            text (Errors.errorToString apiError)


mapHeight : Int
mapHeight =
    500


viewMap : Model -> Element Msg
viewMap model =
    -- el [ paddingEach { edges | right = 20 }, width fill, height shrink ]
    column
        [ height (px mapHeight)
        , width fill
        , Style.clipStyle
        , Border.solid
        , Border.color Colors.darkness
        , Border.width 1
        , clip
        , Background.color (rgba 0 0 0 0.05)
        ]
        [ row [ width fill, height fill ]
            [ StyledElement.googleMap
                [ inFront
                    (case model.selectedTrip of
                        Nothing ->
                            none

                        Just trip ->
                            case pointAt model.sliderValue trip of
                                Nothing ->
                                    none

                                Just point ->
                                    el
                                        [ paddingXY 16 8
                                        , centerX
                                        , moveDown 20
                                        , Background.color (Colors.withAlpha Colors.white 0.5)
                                        , Style.blurredStyle
                                        , Border.rounded 4
                                        , Border.color Colors.sassyGrey
                                        , Border.width 1
                                        , Style.elevated2
                                        ]
                                        (el (moveDown 1 :: centerX :: Style.labelStyle ++ [ Font.size 15, Font.semiBold, Font.color Colors.purple ]) (text (String.fromFloat point.speed ++ " km/h")))
                    )
                ]
            , case model.selectedTrip of
                Just trip ->
                    el
                        [ width (px 250)
                        , height fill
                        , Background.color Colors.white
                        , Border.color (Colors.withAlpha Colors.darkness 0.5)
                        , Border.widthEach { edges | left = 1 }
                        ]
                        (viewStudentActivities trip.studentActivities (Session.timeZone model.session))

                Nothing ->
                    none
            ]
        , case model.selectedTrip of
            Just trip ->
                viewSlider model (Session.timeZone model.session) trip

            Nothing ->
                none
        ]


sliderHeight : Int
sliderHeight =
    93


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
        , height (px sliderHeight)
        , Background.color Colors.white
        , width fill
        ]
        [ -- row [] [ viewSlider model zone trip,
          el [ width (fillPortion 1), width (fillPortion 1) ] none
        , column [ width (fillPortion 40) ]
            [ Input.slider
                [ height (px 48)
                , Element.below (el (Style.captionStyle ++ [ alignLeft ]) (text (String.toUpper (Utils.DateFormatter.timeFormatter zone trip.startTime))))
                , Element.below (el (Style.captionStyle ++ [ alignRight ]) (text (String.toUpper (Utils.DateFormatter.timeFormatter zone trip.endTime))))

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
            -- StyledElement.plainButton [ Style.ignoreCss ]
            --     { onPress = Nothing
            --     , label =
            row
                ([ height (px 64)
                 , spacing 8
                 , width fill
                 , paddingXY 12 11
                 , Background.color (rgb 1 1 1)
                 , Style.animatesShadow
                 ]
                    ++ selectionStyles
                )
                [ column [ spacing 8 ]
                    [ el (timeStyle ++ [ alignRight, Font.color Colors.darkText ]) (text (String.toUpper (Utils.DateFormatter.timeFormatter timezone activity.time)))
                    ]
                , el [ width (px 3), height fill, Background.color Colors.darkGreen ] none
                , column [ spacing 8, width fill ]
                    [ textColumn (spacing 4 :: routeStyle)
                        [ el [] (text "Tony G.")
                        , el [] (text (String.replace "_" " " activity.activity))
                        ]
                    ]
                ]

        -- }
    in
    column
        [ height (px (mapHeight - sliderHeight))
        , scrollbarY
        ]
        (List.map viewActivity activities)



-- (el [ Background.color Colors.backgroundGreen, height (px 34) ] (el [ centerX, centerY ] (text "Student Movement"))
-- (el [ Background.color Colors.backgroundGreen, height (px 34) ] (text "Student Movement")
-- :: List.map viewActivity activities
-- )


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
viewTrips { selectedGroup, selectedTrip, session, groupedTrips } =
    case selectedGroup of
        Nothing ->
            if groupedTrips == [] then
                el [ centerX, centerY ] (text "No trips available")

            else
                el [ centerX, centerY ] (text "Select a date from below")

        Just selectedGroup_ ->
            wrappedRow [ spacing 12, width fill ] (List.map (viewTrip selectedTrip (Session.timeZone session)) (List.reverse (Tuple.second selectedGroup_)))



-- viewGroupedTrips : Maybe Trip -> Time.Zone -> GroupedTrips -> Element Msg
-- viewGroupedTrips selectedTrip timezone ( month, trips ) =
--     column [ spacing 8 ]
--         [ el (Font.size 20 :: Font.bold :: Style.defaultFontFace) (text month)
--         , wrappedRow [ spacing 12 ] (List.map (viewTrip selectedTrip timezone) trips)
--         ]


viewTrip : Maybe Trip -> Time.Zone -> LightWeightTrip -> Element Msg
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
            if Just trip.id == Maybe.andThen (.id >> Just) selectedTrip then
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
         , Events.onClick (ClickedOn trip.id)
         , Style.animatesShadow
         ]
            ++ selectionStyles
        )
        [ column [ spacing 8 ]
            [ el (alignRight :: timeStyle ++ [ Font.color Colors.darkText ])
                (text (String.toUpper (Utils.DateFormatter.timeFormatter timezone trip.startTime)))
            , el (alignRight :: timeStyle)
                (text (String.toUpper (Utils.DateFormatter.timeFormatter timezone trip.endTime)))

            -- , el routeStyle (text trip.route)
            ]
        , el [ width (px 3), height fill, Background.color Colors.darkGreen ] none
        , column [ spacing 8 ]
            [ el routeStyle (text trip.travelTime)

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
    if not model.showingOngoingTrip then
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
            [ el [ width fill, height (px 2), Background.color Colors.semiDarkText ] none
            , row ([ width fill, scrollbarX, Style.reverseScrolling ] ++ Style.header2Style ++ [ paddingEach { edges | bottom = 16 } ])
                (List.map viewScrollTrip model.groupedTrips)
            ]

    else
        none



-- HTTP


fetchTripsForBus : Session -> Int -> Cmd Msg
fetchTripsForBus session bus_id =
    let
        params =
            { bus_id = bus_id }
    in
    Api.get session (Endpoint.trips params) (list tripDecoder)
        |> Cmd.map ReceivedTripsResponse


fetchReportsForTrip : Session -> Int -> Cmd Msg
fetchReportsForTrip session tripID =
    Api.get session (Endpoint.reportsForTrip tripID) tripDetailsDecoder
        |> Cmd.map ReceivedTripDetailsResponse


groupTrips : List LightWeightTrip -> Time.Zone -> List GroupedTrips
groupTrips trips timezone =
    Utils.GroupBy.date timezone .startTime trips


toGPS : Location -> { lat : Float, lng : Float }
toGPS location =
    { lat = location.latitude
    , lng = location.longitude
    }


pointAt : Int -> Trip -> Maybe Report
pointAt index trip =
    List.head (List.drop index trip.reports)


drawPath trip sliderValue =
    Cmd.batch
        [ Ports.bulkDrawPath
            [ { routeID = 0
              , path =
                    trip.reports
                        |> List.take (sliderValue + 1)
                        |> List.map .location
              , highlighted = True
              }
            , { routeID = 1
              , path =
                    trip.reports
                        |> List.drop sliderValue
                        |> List.map .location
              , highlighted = False
              }
            ]
        ]


tabBarItems model mapper =
    if model.showingOngoingTrip then
        [ TabBar.Button
            { title = "Show Trip History"
            , icon = Icons.timeline
            , onPress = ShowHistoricalTrips |> mapper
            }
        ]

    else
        [ TabBar.Button
            { title = "Show Ongoing Trip"
            , icon = Icons.timeline
            , onPress = ShowCurrentTrip |> mapper
            }
        ]
