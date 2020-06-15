module Pages.Buses.Bus.FuelHistoryPage exposing
    ( Model
    , Msg
    , init
    , tabBarItems
    , update
    , view
    , viewButtons
    , viewFooter
    )

import Api
import Api.Endpoint as Endpoint
import Browser.Dom
import Colors
import Date
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html.Attributes exposing (id)
import Icons
import Json.Decode as Decode exposing (Decoder, int, list, string)
import Layout.TabBar as TabBar exposing (TabBarItem(..))
import Models.FuelReport as FuelReport exposing (ConsumptionRate, Distance, FuelReport, Volume, fuelRecordDecoder)
import Navigation
import RemoteData exposing (..)
import Session exposing (Session)
import Statistics
import Style exposing (edges)
import StyledElement
import StyledElement.Footer as Footer
import StyledElement.FuelGraph
import StyledElement.WebDataView as WebDataView
import Task
import Time
import Utils.GroupBy


type alias Model =
    { session : Session
    , busID : Int
    , reports : WebData (List GroupedReports)
    , statistics : Maybe Statistics
    , chartData : Maybe ChartData
    }


{-| Statistics for all the reports
-}
type alias Statistics =
    { stdDev : Float
    , mean : Float
    }


type alias ChartData =
    { data :
        List
            { date : Time.Posix
            , consumptionOnDate : ConsumptionRate
            , runningAverage : ConsumptionRate
            }
    , month : String
    }


type alias AnnotatedReport =
    { report : FuelReport
    , cumulativeFuelPurchased : Volume
    , distanceSinceLastFueling : Distance
    }


type alias GroupedReports =
    ( String, List AnnotatedReport )


init : Int -> Session -> ( Model, Cmd Msg )
init busID session =
    ( { session = session
      , busID = busID
      , reports = Loading
      , chartData = Nothing
      , statistics = Nothing
      }
    , fetchFuelHistory session busID
    )



-- UPDATE


type Msg
    = RecordsResponse (WebData ( List AnnotatedReport, List GroupedReports ))
      -- | Show (GroupedReports)
    | Show String
    | CreateFuelReport
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        CreateFuelReport ->
            ( model, Navigation.rerouteTo model (Navigation.CreateFuelReport model.busID) )

        Show month ->
            case model.reports of
                Success reports ->
                    let
                        matching =
                            List.head (List.filter (Tuple.first >> (\x -> x == month)) reports)
                    in
                    case matching of
                        Just ( month_, reports_ ) ->
                            ( { model
                                | chartData =
                                    Just
                                        { month = month_
                                        , data =
                                            reports_
                                                |> List.map
                                                    (\{ report, distanceSinceLastFueling, cumulativeFuelPurchased } ->
                                                        { date = report.date
                                                        , consumptionOnDate = FuelReport.consumption distanceSinceLastFueling report.volume
                                                        , runningAverage = FuelReport.consumption report.totalDistanceCovered cumulativeFuelPurchased
                                                        }
                                                    )
                                        }
                              }
                            , Browser.Dom.setViewportOf "view" 0 0
                                |> Task.onError (\_ -> Task.succeed ())
                                |> Task.perform (\_ -> NoOp)
                            )

                        _ ->
                            ( { model | chartData = Nothing }, Cmd.none )

                _ ->
                    ( { model | chartData = Nothing }, Cmd.none )

        RecordsResponse response ->
            case response of
                Success ( distanced, grouped ) ->
                    -- Select the head as the default
                    let
                        ( chartData, statistics ) =
                            case List.head grouped of
                                Just ( monthName, reports ) ->
                                    let
                                        fuelConsumptions =
                                            reports
                                                |> List.map (\x -> FuelReport.consumption x.distanceSinceLastFueling x.report.volume)
                                                |> List.map FuelReport.consumptionToFloat

                                        stdDev =
                                            Statistics.deviation fuelConsumptions

                                        mean =
                                            (fuelConsumptions |> List.foldl (+) 0)
                                                / toFloat (List.length fuelConsumptions)
                                    in
                                    ( Just
                                        { month = monthName
                                        , data =
                                            reports
                                                |> List.map
                                                    (\{ report, distanceSinceLastFueling, cumulativeFuelPurchased } ->
                                                        { date = report.date
                                                        , consumptionOnDate = FuelReport.consumption distanceSinceLastFueling report.volume
                                                        , runningAverage = FuelReport.consumption report.totalDistanceCovered cumulativeFuelPurchased
                                                        }
                                                    )
                                        }
                                    , case ( stdDev, mean ) of
                                        ( Just stdDev_, mean_ ) ->
                                            Just
                                                { stdDev = stdDev_
                                                , mean = mean_
                                                }

                                        _ ->
                                            Nothing
                                    )

                                Nothing ->
                                    ( Nothing, Nothing )
                    in
                    ( { model
                        | reports = Success grouped
                        , statistics = statistics
                        , chartData = chartData
                      }
                    , Cmd.none
                    )

                Failure e ->
                    ( { model | reports = Failure e }, Cmd.none )

                Loading ->
                    ( { model | reports = Loading }, Cmd.none )

                NotAsked ->
                    ( { model | reports = NotAsked }, Cmd.none )



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    let
        totalCost =
            List.foldl (\x y -> y + totalForGroup (Tuple.second x)) 0
    in
    column
        [ height (px viewHeight)
        , width fill
        , clip
        , scrollbarY
        , Border.solid
        , htmlAttribute (id "view")
        , htmlAttribute (Html.Attributes.style "scroll-behavior" "smooth")
        , Style.animatesAll
        ]
        [ viewGraph model
        , WebDataView.view model.reports
            (\reports ->
                column []
                    [ --     row (Style.header2Style ++ [ alignLeft, width fill, Font.color Colors.black, spacing 30 ])
                      --     [ text "Total Paid"
                      --     , el [ Font.size 21, Font.color Colors.darkGreen ] (text ("KES. " ++ String.fromInt (totalCost reports)))
                      --     ]
                      -- ,
                      viewGroupedReports model reports
                    ]
            )
        ]


viewGraph : Model -> Element msg
viewGraph model =
    case model.chartData of
        Just chartData ->
            el
                [ width (fill |> maximum 900)
                , moveRight 20
                , inFront
                    (el (centerX :: Style.header2Style)
                        (text ("Fuel Consumption (km/l) for " ++ chartData.month))
                    )
                , behindContent
                    (el [ alignRight, alignBottom, moveDown 5 ] (text "Date"))
                , inFront
                    (el
                        [ centerY, width (px 1), height (px 1), rotate (-pi / 2), moveDown 60, moveLeft 10 ]
                        (text "Fuel Consumption (km/l)")
                    )
                ]
                (StyledElement.FuelGraph.view
                    chartData.data
                    model.statistics
                    (Session.timeZone model.session)
                )

        Nothing ->
            el [ height (px 300), width fill ]
                (el [ centerX, centerY ]
                    (text "No fuel data available")
                )


viewGroupedReports : Model -> List GroupedReports -> Element Msg
viewGroupedReports model groupedReports =
    let
        selectedMonth =
            model.chartData |> Maybe.map .month

        timezone =
            Session.timeZone model.session

        tableHeader strings attr =
            column Style.tableHeaderStyle
                (List.map
                    (\x -> el attr (text (String.toUpper x)))
                    strings
                )

        rowTextStyle =
            width (fill |> minimum 180) :: Style.tableElementStyle

        viewGroup : ( String, List AnnotatedReport ) -> Element Msg
        viewGroup ( month, reportsForDate ) =
            column [ spacing 12, height fill ]
                [ el
                    [ paddingXY 10 4
                    , centerX
                    , Border.widthEach { edges | bottom = 1 }
                    , Border.color (Colors.withAlpha Colors.darkness 0.2)
                    ]
                    (row [ spacing 10 ]
                        [ el (Style.header2Style ++ [ padding 0, centerX ]) (text month)
                        , if selectedMonth /= Just month then
                            StyledElement.plainButton []
                                { label = Icons.show [ mouseOver [ alpha 1 ], alpha 0.5 ]
                                , onPress = Just (Show month)
                                }

                          else
                            none
                        ]
                    )
                , table [ spacingXY 30 15 ]
                    { data = reportsForDate
                    , columns =
                        [ { header = tableHeader [ "DATE" ] []
                          , width = fill
                          , view =
                                \x ->
                                    let
                                        dateText =
                                            x.report.date |> Date.fromPosix timezone |> Date.format "MMM ddd"
                                    in
                                    el rowTextStyle (text dateText)
                          }
                        , { header = tableHeader [ "FUEL CONSUMPTION", "(KM/L)" ] [ alignRight ]
                          , width = fill
                          , view =
                                \x ->
                                    let
                                        consumptionText =
                                            FuelReport.consumption x.distanceSinceLastFueling x.report.volume
                                                |> FuelReport.consumptionToFloat
                                                |> String.fromFloat
                                                |> (\c ->
                                                        case List.head (String.indexes "." c) of
                                                            Nothing ->
                                                                c ++ ".00"

                                                            Just location ->
                                                                let
                                                                    length =
                                                                        String.length c
                                                                in
                                                                String.padRight (length + (2 - (length - location - 1))) '0' c
                                                   )
                                    in
                                    el (rowTextStyle ++ [ Font.alignRight ]) (text consumptionText)
                          }
                        , { header =
                                column (alignRight :: Style.tableHeaderStyle)
                                    [ el [ alignRight ] (text (String.toUpper "DISTANCE "))
                                    , el [ alignRight ] (text (String.toUpper "TRAVELLED (KM)"))
                                    ]
                          , width = fill
                          , view =
                                \x ->
                                    let
                                        distanceText =
                                            if FuelReport.distanceToInt x.distanceSinceLastFueling > 0 then
                                                String.fromInt (FuelReport.distanceToInt x.distanceSinceLastFueling // 1000)

                                            else
                                                "-"
                                    in
                                    el (width fill :: Font.alignRight :: rowTextStyle) (text distanceText)
                          }
                        , { header = tableHeader [ "FUEL COST", "(KES)" ] [ alignRight ]
                          , width = fill
                          , view =
                                \x ->
                                    el (width fill :: Font.alignRight :: rowTextStyle) (text (String.fromInt x.report.cost))
                          }
                        ]
                    }
                , column [ alignRight, spacing 4 ]
                    [ el [ width fill, height (px 2), Background.color (rgb255 96 96 96) ] none
                    , el (Font.alignRight :: Font.bold :: Style.tableElementStyle) (text ("KES. " ++ String.fromInt (totalForGroup reportsForDate)))
                    ]
                ]
    in
    column
        [ scrollbarY
        , height fill
        , width fill
        , paddingXY 0 10
        ]
        (List.map viewGroup groupedReports)


viewButtons model =
    el
        [ alignRight, paddingEach { edges | top = 12 } ]
        none


viewFooter : Model -> Element Msg
viewFooter _ =
    Footer.coloredView ()
        (always "Summary")
        [ { page = (), body = "", action = NoOp, highlightColor = Colors.darkGreen }
        ]


fetchFuelHistory : Session -> Int -> Cmd Msg
fetchFuelHistory session bus_id =
    Api.get session (Endpoint.fuelReports bus_id) (list fuelRecordDecoder)
        |> Cmd.map (groupReports (Session.timeZone session) >> RecordsResponse)


groupReports :
    Time.Zone
    -> WebData (List FuelReport)
    -> WebData ( List AnnotatedReport, List GroupedReports )
groupReports timezone reports_ =
    case reports_ of
        Success reports ->
            let
                sortedReports : List FuelReport
                sortedReports =
                    reports
                        |> List.sortWith compareReports

                distancedReports : List AnnotatedReport
                distancedReports =
                    sortedReports
                        |> List.foldl
                            (\report ( ( totalDistance, cumulativeFuel ), acc ) ->
                                let
                                    totalFuelConsumed : Volume
                                    totalFuelConsumed =
                                        FuelReport.volumeSum cumulativeFuel report.volume

                                    distanceSinceLastFueling : Distance
                                    distanceSinceLastFueling =
                                        FuelReport.distanceDifference report.totalDistanceCovered totalDistance
                                in
                                ( ( report.totalDistanceCovered, totalFuelConsumed )
                                , { report = report
                                  , cumulativeFuelPurchased = totalFuelConsumed
                                  , distanceSinceLastFueling = distanceSinceLastFueling
                                  }
                                    :: acc
                                )
                            )
                            ( ( FuelReport.distance 0, FuelReport.volume 0 ), [] )
                        |> Tuple.second
            in
            Success
                ( distancedReports
                , distancedReports
                    |> Utils.GroupBy.attr
                        { groupBy = .report >> .date >> Date.fromPosix timezone >> Date.format "yyyy MM"
                        , nameAs = .report >> .date >> Date.fromPosix timezone >> Date.format "MMM yyyy"
                        , reverse = False
                        }
                )

        Failure error ->
            Failure error

        Loading ->
            Loading

        NotAsked ->
            NotAsked


compareReports : FuelReport -> FuelReport -> Order
compareReports report1 report2 =
    let
        getDate =
            .date >> Time.posixToMillis

        dateOrder =
            compare (getDate report1) (getDate report2)

        distanceOrder =
            compare (FuelReport.distanceToInt report1.totalDistanceCovered) (FuelReport.distanceToInt report2.totalDistanceCovered)
    in
    case ( dateOrder, distanceOrder ) of
        ( GT, _ ) ->
            GT

        ( LT, _ ) ->
            LT

        ( _, x ) ->
            x


totalForGroup : List AnnotatedReport -> Int
totalForGroup reports =
    reports
        |> List.foldl
            (\x acc -> acc + (x |> .report |> .cost))
            0


tabBarItems mapper =
    [ TabBar.Button
        { title = "Add Fuel record"
        , icon = Icons.add
        , onPress = CreateFuelReport |> mapper
        }
    ]
