module Pages.Buses.Bus.TripsHistoryPage exposing
    ( Model
    , Msg
    , init
    , ongoingTripEnded
    , ongoingTripUpdated
    , subscriptions
    , tabBarItems
    , update
    , view
    , viewFooter
    , viewOverlay
    )

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
import Errors exposing (Errors)
import Icons
import Json.Decode exposing (Decoder, list)
import Json.Encode as Encode
import Layout.TabBar as TabBar
import Models.Location exposing (Location, Report)
import Models.Route exposing (Route)
import Models.Tile exposing (Tile, newTile)
import Models.Trip as Trip exposing (LightWeightTrip, OngoingTrip, StudentActivity, Trip, ongoingToTrip, ongoingTripDecoder, tripDecoder, tripDetailsDecoder)
import Navigation
import Pages.Buses.Bus.Navigation exposing (BusPage(..))
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import StyledElement.DropDown as Dropdown
import StyledElement.TripSlider as TripSlider
import StyledElement.WebDataView as WebDataView
import Task
import Time
import Utils.DateFormatter
import Utils.GroupBy


type alias Model =
    { busID : Int
    , sliderValue : Int
    , mapVisuals :
        { showDeviations : Bool
        , showGeofence : Bool
        , showStops : Bool
        , showSpeed : Bool
        }
    , showingOngoingTrip : Bool
    , historicalTrips : WebData (List Trip.LightWeightTrip)
    , groupedTrips : List GroupedTrips
    , selectedGroup : Maybe GroupedTrips
    , selectedTrip : Maybe Trip
    , session : Session
    , loadedTrips : Dict Int Trip
    , loadingTrip : WebData Trip
    , ongoingTrip : WebData (Maybe OngoingTrip)
    , needRefreshOngoingTrip : Bool
    , requestedTrip : Maybe Int
    , createRouteForm : Maybe CreateRouteForm
    , isPlaying : Bool
    }


type alias GroupedTrips =
    ( String, List LightWeightTrip )


type alias CreateRouteForm =
    { path : List Location
    , tripID : Int
    , routes : WebData (List Route)
    , selectedRoute : UpdateRoute
    , routeDropdownState : Dropdown.State Route
    , problems : List (Errors.Errors Problem)
    , update : WebData ()
    }


type Problem
    = EmptyRoute
    | EmptyRouteName


type UpdateRoute
    = NewRoute String
    | ExistingRoute (Maybe Route)


type ValidForm
    = ValidNewRoute { tripID : Int, routeName : String }
    | ValidExistingRoute { tripID : Int, routeID : Int }


newCreateRouteForm : Trip -> CreateRouteForm
newCreateRouteForm trip =
    { path = trip.reports |> List.map .location
    , tripID = trip.id
    , routes = Loading
    , selectedRoute = NewRoute ""
    , routeDropdownState = Dropdown.init "routeDropdown"
    , problems = []
    , update = NotAsked
    }


init : Int -> Session -> ( Model, Cmd Msg )
init busID session =
    let
        model =
            { busID = busID
            , sliderValue = 0
            , mapVisuals =
                { showDeviations = True
                , showGeofence = False
                , showStops = False
                , showSpeed = False
                }
            , historicalTrips = RemoteData.NotAsked
            , showingOngoingTrip = True
            , groupedTrips = []
            , selectedGroup = Nothing
            , selectedTrip = Nothing
            , session = session
            , loadedTrips = Dict.fromList []
            , loadingTrip = NotAsked
            , requestedTrip = Nothing
            , ongoingTrip = RemoteData.Loading
            , needRefreshOngoingTrip = False
            , createRouteForm = Nothing
            , isPlaying = False
            }
    in
    ( model
    , Cmd.batch
        [ if model.showingOngoingTrip then
            fetchOngoingTripForBus session busID

          else
            fetchHistoricalTripsForBus model.session model.busID
        ]
    )



-- UPDATE


type Msg
    = AdjustedValue Int
    | ReceivedTripsResponse (WebData (List LightWeightTrip))
    | ReceivedOngoingTripResponse (WebData (Maybe OngoingTrip))
    | ReceivedTripDetailsResponse (WebData Trip)
    | ClickedOn Int
    | SelectedGroup GroupedTrips
      ------
    | ToggledShowGeofence Bool
    | ToggledShowStops Bool
    | ToggledShowSpeed Bool
    | ToggledShowDeviation Bool
      ------
    | ShowHistoricalTrips
    | ShowCurrentTrip
      ------
    | CreateRouteFromTrip
    | CancelRouteCreation
    | OngoingTripUpdated Json.Decode.Value
    | OngoingTripEnded
      ------
    | AdvanceTrip
    | StartPlaying
    | StopPlaying
      ------
    | UpdatedRouteName String
    | SetSaveToRoute UpdateRoute
    | ReceivedRoutesResponse (WebData (List Route))
    | RouteDropdownMsg (Dropdown.Msg Route)
    | SubmitUpdate
    | ReceivedUpdateResponse (WebData ())


type UpdateMsg
    = NoOngoingTrip
    | NewTrip OngoingTrip
    | NewReport Report
    | NewStudentActivity StudentActivity


ongoingTripUpdated =
    OngoingTripUpdated


ongoingTripEnded =
    OngoingTripEnded


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        mapVisuals =
            model.mapVisuals
    in
    case msg of
        AdjustedValue sliderValue ->
            let
                currentPoint =
                    case model.selectedTrip of
                        Nothing ->
                            Nothing

                        Just trip ->
                            Trip.pointAt sliderValue trip

                scrollToStudentActivity =
                    Cmd.none
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
                                drawPath trip sliderValue model.mapVisuals.showDeviations
                        , scrollToStudentActivity
                        ]
                    )

        ToggledShowGeofence show ->
            ( { model | mapVisuals = { mapVisuals | showGeofence = show } }, Cmd.none )

        ToggledShowStops show ->
            ( { model | mapVisuals = { mapVisuals | showStops = show } }, Cmd.none )

        ToggledShowSpeed show ->
            ( { model | mapVisuals = { mapVisuals | showSpeed = show } }, Cmd.none )

        ToggledShowDeviation show ->
            ( { model | mapVisuals = { mapVisuals | showDeviations = show } }
            , Ports.setDeviationTileVisible show
            )

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
                            Errors.toMsg error

                        _ ->
                            Cmd.none
            in
            ( { model | historicalTrips = response, groupedTrips = groupedTrips }
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
            if Just tripID == (model.selectedTrip |> Maybe.map .id) then
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
                            [ case Trip.pointAt model.sliderValue loadedTrip of
                                Nothing ->
                                    Ports.deselectPoint ()

                                Just report ->
                                    Ports.selectPoint
                                        { location = report.location
                                        , bearing = report.bearing
                                        }
                            , drawPath loadedTrip 0 model.mapVisuals.showDeviations
                            , Ports.cleanMap ()
                            , Ports.fitBounds
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
                , selectedTrip =
                    case model.ongoingTrip of
                        Success (Just trip) ->
                            Just (ongoingToTrip trip)

                        _ ->
                            Nothing
              }
            , Ports.deselectPoint ()
            )

        ShowHistoricalTrips ->
            ( { model
                | showingOngoingTrip = False
                , historicalTrips =
                    if model.historicalTrips == NotAsked then
                        Loading

                    else
                        model.historicalTrips
              }
            , Cmd.batch
                [ Ports.cleanMap ()
                , if model.historicalTrips == NotAsked then
                    fetchHistoricalTripsForBus model.session model.busID

                  else
                    Cmd.none
                ]
            )

        ShowCurrentTrip ->
            selectOngoingTrip { model | showingOngoingTrip = True, createRouteForm = Nothing }

        CreateRouteFromTrip ->
            case model.selectedTrip of
                Just trip ->
                    let
                        form =
                            newCreateRouteForm trip
                    in
                    ( { model | createRouteForm = Just form }
                    , Cmd.batch
                        [ fetchRoutes model.session
                        , Ports.cleanMap ()
                        , Ports.disableClickListeners ()
                        , Ports.drawEditablePath
                            { routeID = 0
                            , path = form.path
                            , highlighted = False
                            , editable = False
                            }
                        ]
                    )

                Nothing ->
                    ( model, Cmd.none )

        UpdatedRouteName name ->
            ( { model
                | createRouteForm =
                    model.createRouteForm
                        |> Maybe.map
                            (\x ->
                                case x.selectedRoute of
                                    NewRoute _ ->
                                        { x | selectedRoute = NewRoute name }

                                    _ ->
                                        x
                            )
              }
            , Cmd.none
            )

        CancelRouteCreation ->
            ( { model | createRouteForm = Nothing }, Cmd.none )

        SetSaveToRoute selectedRoute ->
            ( { model
                | createRouteForm =
                    model.createRouteForm
                        |> Maybe.map
                            (\x ->
                                { x | selectedRoute = selectedRoute }
                            )
              }
            , Cmd.none
            )

        SubmitUpdate ->
            case model.createRouteForm of
                Just form ->
                    case validateForm form of
                        Ok validForm ->
                            ( { model
                                | createRouteForm =
                                    Just
                                        { form
                                            | problems = []
                                            , update = Loading
                                        }
                              }
                            , submitRouteUpdate model.session validForm
                            )

                        Err problems ->
                            ( { model | createRouteForm = Just { form | problems = Errors.toValidationErrors problems } }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        ReceivedUpdateResponse updateResponse ->
            case model.createRouteForm of
                Nothing ->
                    ( model, Cmd.none )

                Just form ->
                    if RemoteData.isSuccess updateResponse then
                        ( { model | createRouteForm = Nothing }
                        , Cmd.none
                        )

                    else
                        ( { model | createRouteForm = Just { form | update = updateResponse } }
                        , Cmd.none
                        )

        RouteDropdownMsg subMsg ->
            case model.createRouteForm of
                Nothing ->
                    ( model, Cmd.none )

                Just createRouteForm ->
                    let
                        ( _, config, options ) =
                            routeDropDown createRouteForm

                        ( state, cmd ) =
                            Dropdown.update config subMsg createRouteForm.routeDropdownState options
                    in
                    ( { model | createRouteForm = Just { createRouteForm | routeDropdownState = state } }
                    , cmd
                    )

        ReceivedRoutesResponse routes ->
            case model.createRouteForm of
                Nothing ->
                    ( model, Cmd.none )

                Just form ->
                    ( { model | createRouteForm = Just { form | routes = routes } }
                    , Cmd.none
                    )

        ReceivedOngoingTripResponse ongoingTrip ->
            selectOngoingTrip { model | ongoingTrip = ongoingTrip }

        OngoingTripEnded ->
            ( { model
                | selectedTrip = Nothing
                , ongoingTrip = NotAsked
                , needRefreshOngoingTrip = True
              }
            , if model.showingOngoingTrip then
                Navigation.Bus model.busID RouteHistory
                    |> Navigation.rerouteTo model

              else
                Cmd.none
            )

        OngoingTripUpdated updateValue ->
            let
                change =
                    updateValue
                        |> Json.Decode.decodeValue
                            (Json.Decode.oneOf
                                [ Json.Decode.map NewTrip ongoingTripDecoder
                                , Json.Decode.map NewReport Models.Location.reportDecoder
                                , Json.Decode.map NewStudentActivity Trip.studentActivityDecoder
                                , Json.Decode.null NoOngoingTrip
                                ]
                            )
                        |> Result.toMaybe

                newModel =
                    change
                        |> Maybe.map
                            (\tripUpdate ->
                                case model.ongoingTrip of
                                    Success (Just trip) ->
                                        case tripUpdate of
                                            NewTrip newTrip ->
                                                { model | ongoingTrip = Success (Just newTrip) }

                                            NewReport report ->
                                                { model | ongoingTrip = Success (Just { trip | reports = report :: trip.reports }) }

                                            NewStudentActivity report ->
                                                { model | ongoingTrip = Success (Just { trip | studentActivities = report :: trip.studentActivities }) }

                                            NoOngoingTrip ->
                                                { model | ongoingTrip = Success Nothing }

                                    _ ->
                                        case tripUpdate of
                                            NewTrip trip ->
                                                { model | ongoingTrip = Success (Just trip) }

                                            _ ->
                                                model
                            )
                        |> Maybe.withDefault model
            in
            ( if model.showingOngoingTrip then
                { newModel
                    | selectedTrip =
                        model.ongoingTrip
                            |> RemoteData.toMaybe
                            |> Maybe.withDefault Nothing
                            |> Maybe.map ongoingToTrip
                }

              else
                newModel
            , Cmd.none
            )

        AdvanceTrip ->
            if model.isPlaying then
                ( model
                , Task.succeed (AdjustedValue (model.sliderValue + 1)) |> Task.perform identity
                )

            else
                ( model, Cmd.none )

        StartPlaying ->
            ( { model | isPlaying = True }
            , Cmd.none
            )

        StopPlaying ->
            ( { model | isPlaying = False }
            , Cmd.none
            )


selectOngoingTrip : Model -> ( Model, Cmd Msg )
selectOngoingTrip model =
    case model.ongoingTrip of
        Success (Just trip) ->
            let
                sliderValue =
                    List.length trip.reports - 1

                bearing =
                    trip.reports
                        |> List.drop 1
                        |> List.head
                        |> Maybe.map .bearing
                        |> Maybe.withDefault 0

                lastReport =
                    trip.reports
                        |> List.head
            in
            ( { model
                | selectedTrip = Just (ongoingToTrip trip)
                , sliderValue = (List.length <| trip.reports) - 1
              }
            , Cmd.batch
                [ Ports.initializeMaps
                , case lastReport of
                    Nothing ->
                        Cmd.none

                    Just report ->
                        Ports.selectPoint
                            { location = report.location
                            , bearing = bearing
                            }
                , drawPath (ongoingToTrip trip) sliderValue model.mapVisuals.showDeviations
                , Ports.cleanMap ()
                ]
            )

        _ ->
            ( { model | selectedTrip = Nothing }, Cmd.none )



-- VIEW


view : Model -> Int -> Element Msg
view model viewWidth =
    let
        viewContents =
            always
                (column [ width fill, height fill, spacing 16 ]
                    [ viewMap model viewWidth
                    , viewMapOptions model.mapVisuals
                    , if not model.showingOngoingTrip then
                        viewTrips model
                        -- viewFooter has the rest

                      else
                        WebDataView.view model.ongoingTrip
                            (\trip ->
                                case trip of
                                    Just _ ->
                                        none

                                    Nothing ->
                                        el [ width fill, height fill ]
                                            (column [ centerX, centerY ]
                                                [ el [ centerX ] (text "No trip in progress")
                                                , el [ centerX ] (text "Click below to see past trips")
                                                ]
                                            )
                            )
                    ]
                )
    in
    if model.showingOngoingTrip then
        WebDataView.view model.ongoingTrip viewContents

    else
        WebDataView.view model.historicalTrips viewContents


mapHeight : Int
mapHeight =
    500


viewMap : Model -> Int -> Element Msg
viewMap model viewWidth =
    column
        [ height (px mapHeight)
        , width fill
        , Border.solid
        , Border.color Colors.darkness
        , Border.width 1
        , clip
        , Background.color Colors.semiDarkness
        ]
        (if model.createRouteForm == Nothing then
            [ row [ width fill, height fill ]
                [ StyledElement.googleMap
                    [ inFront
                        (case model.selectedTrip of
                            Nothing ->
                                none

                            Just trip ->
                                case Trip.pointAt model.sliderValue trip of
                                    Nothing ->
                                        none

                                    Just point ->
                                        row
                                            [ paddingXY 16 8
                                            , centerX
                                            , moveDown 20
                                            , Background.color Colors.white

                                            -- , Background.color (Colors.withAlpha Colors.white 0.5)
                                            -- , Style.blurredStyle
                                            , Border.rounded 4
                                            , Border.color Colors.sassyGreyDark
                                            , Border.width 2
                                            , Style.elevated2
                                            , spacing 8
                                            ]
                                            [ el
                                                (Style.labelStyle
                                                    ++ [ moveDown 1
                                                       , centerX
                                                       , Font.size 15
                                                       , Font.semiBold
                                                       , Font.color Colors.purple
                                                       ]
                                                )
                                                (text (String.fromFloat point.speed ++ " km/h"))
                                            , el
                                                [ width (px 2)
                                                , height fill
                                                , Background.color (Colors.withAlpha Colors.darkness 0.6)
                                                ]
                                                none
                                            , if model.isPlaying then
                                                el [ pointer, Events.onClick StopPlaying ]
                                                    (Icons.stop [ Colors.fillDarkness, alpha 0.87 ])

                                              else
                                                el [ pointer, Events.onClick StartPlaying ]
                                                    (Icons.play [ Colors.fillDarkness, alpha 0.87 ])
                                            ]
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
                    TripSlider.view
                        { sliderValue = model.sliderValue
                        , zone = Session.timeZone model.session
                        , trip = trip
                        , onAdjustValue = AdjustedValue
                        , viewWidth = viewWidth
                        , showSpeed = model.mapVisuals.showSpeed
                        }

                Nothing ->
                    none
            ]

         else
            []
        )


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
        [ height (px (mapHeight - TripSlider.viewHeight))
        , scrollbarY
        ]
        (List.map viewActivity activities)


viewMapOptions :
    { a
        | showDeviations : Bool
        , showSpeed : Bool
    }
    -> Element Msg
viewMapOptions { showDeviations, showSpeed } =
    row [ paddingXY 10 0, spacing 110 ]
        [ Input.checkbox []
            { onChange = ToggledShowSpeed
            , icon = StyledElement.checkboxIcon
            , checked = showSpeed
            , label =
                Input.labelRight Style.labelStyle
                    (text "Show Speed Graph")
            }
        , Input.checkbox []
            { onChange = ToggledShowDeviation
            , icon = StyledElement.checkboxIcon
            , checked = showDeviations
            , label =
                Input.labelRight Style.labelStyle
                    (text "Show Deviations")
            }
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
            if Just trip.id == (selectedTrip |> Maybe.map .id) then
                [ Border.color (rgb255 97 165 145)
                , moveUp 2
                , Border.shadow { offset = ( 0, 12 ), blur = 20, size = 0, color = rgba255 97 165 145 0.3 }
                ]

            else
                [ Border.color (rgba255 197 197 197 0.5)
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
         , pointer
         ]
            ++ selectionStyles
        )
        [ column [ spacing 8 ]
            [ el (alignRight :: timeStyle ++ [ Font.color Colors.darkText ])
                (text (String.toUpper (Utils.DateFormatter.timeFormatter timezone trip.startTime)))
            , el (alignRight :: timeStyle)
                (text (String.toUpper (Utils.DateFormatter.timeFormatter timezone trip.endTime)))
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


viewOverlay : Model -> Int -> Element Msg
viewOverlay model viewHeight =
    let
        showOverlay =
            model.createRouteForm /= Nothing

        isCreateRoute a =
            case a of
                NewRoute _ ->
                    True

                _ ->
                    False

        editing =
            model.createRouteForm
                |> Maybe.map (\form -> not (isCreateRoute form.selectedRoute))
                |> Maybe.withDefault False

        ( editBackground, createBackground ) =
            if editing then
                ( Colors.backgroundPurple, Colors.white )

            else
                ( Colors.white, Colors.backgroundPurple )
    in
    el
        (Style.animatesAll
            :: width fill
            :: height fill
            :: paddingXY 40 30
            :: behindContent
                (Input.button
                    [ width fill
                    , height fill
                    , Background.color (Colors.withAlpha Colors.black 0.6)
                    , Style.blurredStyle
                    , Style.clickThrough
                    ]
                    { onPress = Maybe.Nothing
                    , label = none
                    }
                )
            :: (if showOverlay then
                    [ alpha 1, Style.nonClickThrough ]

                else
                    [ alpha 0, Style.clickThrough ]
               )
        )
        (if showOverlay then
            el [ Style.nonClickThrough, scrollbarY, centerX, centerY, Background.color Colors.white, Style.elevated2, Border.rounded 5 ]
                (column [ spacing 20, padding 40 ]
                    ([ el Style.header2Style (text "Save trip to route")
                     , el [ width (px 500), height (px 400) ] (StyledElement.googleMap [])
                     , el [ width fill, Border.color Colors.purple, Border.width 2, Border.rounded 5 ]
                        (row [ width fill ]
                            [ StyledElement.hoverButton [ Background.color createBackground, Border.rounded 0, width fill ]
                                { icon = Just Icons.add
                                , onPress = Just (SetSaveToRoute (NewRoute ""))
                                , title = "Create Route"
                                }
                            , el [ Background.color Colors.purple, width (px 2), height fill ] none
                            , StyledElement.hoverButton [ Background.color editBackground, Border.rounded 0, width fill ]
                                { icon = Just Icons.edit
                                , onPress = Just (SetSaveToRoute (ExistingRoute Nothing))
                                , title = "Update Route"
                                }
                            ]
                        )
                     ]
                        ++ (case model.createRouteForm of
                                Nothing ->
                                    []

                                Just form ->
                                    case form.selectedRoute of
                                        NewRoute name ->
                                            [ column [ spacing 20, width fill ]
                                                [ StyledElement.textInput [ width (fill |> minimum 300) ]
                                                    { title = "Route Name"
                                                    , caption = Nothing
                                                    , errorCaption = Errors.captionFor form.problems "name" [ EmptyRouteName ]
                                                    , value = name
                                                    , onChange = UpdatedRouteName
                                                    , placeholder = Nothing
                                                    , ariaLabel = "Password input"
                                                    , icon = Nothing
                                                    }
                                                ]
                                            ]

                                        _ ->
                                            [ WebDataView.view form.routes
                                                (\routes ->
                                                    Dropdown.viewFromModel form routeDropDown
                                                )
                                            ]
                           )
                    )
                )

         else
            none
        )


routeDropDown : CreateRouteForm -> ( Element Msg, Dropdown.Config Route Msg, List Route )
routeDropDown form =
    let
        routes =
            case form.routes of
                Success routes_ ->
                    routes_

                _ ->
                    []

        problems =
            form.problems
    in
    StyledElement.dropDown
        [ width
            (fill
                |> maximum 300
            )
        , alignTop
        ]
        { ariaLabel = "Select bus dropdown"
        , caption = Just "Which route do you want to update?"
        , prompt = Nothing
        , dropDownMsg = RouteDropdownMsg
        , dropdownState = form.routeDropdownState
        , errorCaption = Errors.captionFor problems "id" [ EmptyRoute ]
        , icon = Just Icons.pin
        , onSelect = ExistingRoute >> SetSaveToRoute
        , options = routes
        , title = "Route"
        , toString = .name
        , isLoading = False
        }



-- HTTP


validateForm : CreateRouteForm -> Result (List ( Problem, String )) ValidForm
validateForm form =
    case form.selectedRoute of
        NewRoute routeName ->
            if String.isEmpty (String.trim routeName) then
                Err [ ( EmptyRouteName, "Required" ) ]

            else
                Ok
                    (ValidNewRoute
                        { tripID = form.tripID
                        , routeName = routeName
                        }
                    )

        ExistingRoute Nothing ->
            Err [ ( EmptyRoute, "Required" ) ]

        ExistingRoute (Just route) ->
            Ok
                (ValidExistingRoute
                    { tripID = form.tripID
                    , routeID = route.id
                    }
                )


fetchHistoricalTripsForBus : Session -> Int -> Cmd Msg
fetchHistoricalTripsForBus session busID =
    Api.get session (Endpoint.trips busID) (list tripDecoder)
        |> Cmd.map ReceivedTripsResponse


fetchOngoingTripForBus : Session -> Int -> Cmd Msg
fetchOngoingTripForBus session busID =
    Api.get session (Endpoint.ongoingTrip busID) (Json.Decode.nullable ongoingTripDecoder)
        |> Cmd.map ReceivedOngoingTripResponse


fetchReportsForTrip : Session -> Int -> Cmd Msg
fetchReportsForTrip session tripID =
    Api.get session (Endpoint.reportsForTrip tripID) tripDetailsDecoder
        |> Cmd.map ReceivedTripDetailsResponse


fetchRoutes : Session -> Cmd Msg
fetchRoutes session =
    Api.get session Endpoint.routes (list Models.Route.routeDecoder)
        |> Cmd.map ReceivedRoutesResponse


submitRouteUpdate session form =
    case form of
        ValidExistingRoute { tripID, routeID } ->
            let
                params =
                    Encode.object
                        [ ( "trip_id", Encode.int tripID )
                        ]
            in
            Api.patch session (Endpoint.updateRouteFromTrip routeID) params aDecoder
                |> Cmd.map ReceivedUpdateResponse

        ValidNewRoute { tripID, routeName } ->
            let
                params =
                    Encode.object
                        [ ( "trip_id", Encode.int tripID )
                        , ( "name", Encode.string routeName )
                        ]
            in
            Api.post session Endpoint.newRouteFromTrip params aDecoder
                |> Cmd.map ReceivedUpdateResponse


aDecoder : Decoder ()
aDecoder =
    Json.Decode.succeed ()


groupTrips : List LightWeightTrip -> Time.Zone -> List GroupedTrips
groupTrips trips timezone =
    Utils.GroupBy.date timezone .startTime trips


drawPath :
    Trip
    -> Int
    -> Bool
    -> Cmd Msg
drawPath trip sliderValue deviationsVisible =
    let
        tiles =
            tilesForDeviation trip
    in
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
        , Ports.drawDeviationTiles { tiles | visible = deviationsVisible }
        ]


tilesForDeviation :
    Trip
    -> { correct : List Tile, deviation : List Tile, visible : Bool }
tilesForDeviation trip =
    trip.crossedTiles
        |> List.indexedMap Tuple.pair
        |> List.foldl
            (\( index, location ) acc ->
                if List.member index trip.deviations then
                    { acc | deviation = acc.deviation ++ [ newTile location ] }

                else
                    { acc | correct = acc.correct ++ [ newTile location ] }
            )
            { correct = [], deviation = [], visible = True }


tabBarItems model mapper =
    if model.showingOngoingTrip then
        [ TabBar.Button
            { title = "Show Trip History"
            , icon = Icons.timeline
            , onPress = ShowHistoricalTrips |> mapper
            }
        ]

    else
        case model.selectedTrip of
            Just trip ->
                case model.createRouteForm of
                    Nothing ->
                        [ TabBar.Button
                            { title = "Show Ongoing Trip"
                            , icon = Icons.timeline
                            , onPress = ShowCurrentTrip |> mapper
                            }
                        , TabBar.Button
                            { title = "Save trip to route"
                            , icon = Icons.save
                            , onPress = CreateRouteFromTrip |> mapper
                            }
                        ]

                    Just form ->
                        case form.update of
                            Failure _ ->
                                [ TabBar.Button
                                    { title = "Cancel"
                                    , icon = Icons.close
                                    , onPress = CancelRouteCreation |> mapper
                                    }
                                , TabBar.ErrorButton
                                    { title = "Try Again"
                                    , icon = Icons.save
                                    , onPress = SubmitUpdate |> mapper
                                    }
                                ]

                            Loading ->
                                [ TabBar.LoadingButton
                                ]

                            _ ->
                                [ TabBar.Button
                                    { title = "Cancel"
                                    , icon = Icons.close
                                    , onPress = CancelRouteCreation |> mapper
                                    }
                                , TabBar.Button
                                    { title = "Save"
                                    , icon = Icons.save
                                    , onPress = SubmitUpdate |> mapper
                                    }
                                ]

            Nothing ->
                [ TabBar.Button
                    { title = "Show Ongoing Trip"
                    , icon = Icons.timeline
                    , onPress = ShowCurrentTrip |> mapper
                    }
                ]


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.isPlaying then

        Time.every 500 (always AdvanceTrip)

    else
        Sub.none
