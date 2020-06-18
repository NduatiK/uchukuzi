module Pages.Buses.Bus.FuelHistoryPage exposing
    ( Model
    , Msg
    , init
    , tabBarItems
    , update
    , view
    , viewFooter
    )

import Api
import Api.Endpoint as Endpoint
import Colors
import Date
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html.Attributes exposing (id)
import Icons
import Json.Decode exposing (list)
import Layout.TabBar as TabBar exposing (TabBarItem(..))
import Models.FuelReport as FuelReport exposing (Distance, FuelReport, Volume, fuelRecordDecoder)
import Navigation
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Statistics
import Style exposing (edges)
import StyledElement.WebDataView as WebDataView
import Time
import Utils.GroupBy


type alias Model =
    { session : Session
    , busID : Int
    , reports : WebData (List GroupedReports)
    , statistics : Maybe Statistics
    }


{-| Statistics for all the reports
-}
type alias Statistics =
    { stdDev : Float
    , mean : Float
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
      , statistics = Nothing
      }
    , fetchFuelHistory session busID
    )



-- UPDATE


type Msg
    = RecordsResponse (WebData (List GroupedReports))
    | CreateFuelReport


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CreateFuelReport ->
            ( model, Navigation.rerouteTo model (Navigation.CreateFuelReport model.busID) )

        RecordsResponse response ->
            case response of
                Success grouped ->
                    let
                        reports =
                            grouped
                                |> List.map
                                    (Tuple.second
                                        >> List.reverse
                                    )
                                |> List.reverse
                                |> List.concat

                        fuelConsumptions =
                            reports
                                |> List.map (\x -> FuelReport.consumption x.distanceSinceLastFueling x.report.volume)
                                |> List.map FuelReport.consumptionToFloat

                        stdDev =
                            Statistics.deviation fuelConsumptions

                        mean =
                            (fuelConsumptions |> List.foldl (+) 0)
                                / toFloat (List.length fuelConsumptions)

                        data =
                            reports
                                |> List.map
                                    (\{ report, distanceSinceLastFueling, cumulativeFuelPurchased } ->
                                        { date = report.date
                                        , distanceSinceLastFueling = distanceSinceLastFueling
                                        , consumptionOnDate = FuelReport.consumption distanceSinceLastFueling report.volume
                                        , runningAverage = FuelReport.consumption report.totalDistanceCovered cumulativeFuelPurchased
                                        }
                                    )

                        stats =
                            case ( stdDev, mean ) of
                                ( Just stdDev_, mean_ ) ->
                                    Just
                                        { stdDev = stdDev_
                                        , mean = mean_
                                        }

                                _ ->
                                    Nothing

                        plotData =
                            data |> List.filter (\x -> FuelReport.distanceToInt x.distanceSinceLastFueling /= 0)

                        ( statistics, cmd ) =
                            ( stats
                            , Ports.renderChart
                                { x =
                                    plotData
                                        |> List.map (.date >> Time.posixToMillis)
                                , y =
                                    { consumptionOnDate =
                                        plotData
                                            |> List.map (.consumptionOnDate >> FuelReport.consumptionToFloat)
                                    , runningAverage =
                                        plotData
                                            |> List.map (.runningAverage >> FuelReport.consumptionToFloat)
                                    }
                                , statistics =
                                    stats
                                }
                            )
                    in
                    ( { model
                        | reports = Success grouped
                        , statistics = statistics
                      }
                      -- , Cmd.none
                    , cmd
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
        [ WebDataView.view model.reports
            (\reports ->
                row [ width fill, height fill ]
                    [ column [ width fill, height fill ]
                        [ viewGraph
                        , viewGroupedReports model reports
                        ]
                    , el [ width (px 36) ] none
                    ]
            )
        ]


viewGraph : Element msg
viewGraph =
    el [ width fill, height (px 350), Style.id "chart" ] none


viewGroupedReports : Model -> List GroupedReports -> Element Msg
viewGroupedReports model groupedReports =
    let
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
            column [ spacing 12, height fill, centerX ]
                [ el
                    (Style.header2Style
                        ++ [ padding 0
                           , centerX
                           , paddingXY 10 4
                           , centerX
                           , Border.widthEach { edges | bottom = 1 }
                           , Border.color (Colors.withAlpha Colors.darkness 0.2)
                           ]
                    )
                    (text month)
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
                                    el Style.tableElementStyle (text dateText)
                          }
                        , { header = tableHeader [ "FUEL VOLUME", "(L)" ] [ alignRight ]
                          , width = fill
                          , view =
                                \x ->
                                    let
                                        consumptionText =
                                            x.report.volume
                                                |> FuelReport.volumeToFloat
                                                |> String.fromFloat
                                                |> roundString100
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
                        , { header = tableHeader [ "FUEL CONSUMPTION", "(L/100KM)" ] [ alignRight ]
                          , width = fill
                          , view =
                                \x ->
                                    let
                                        consumption =
                                            FuelReport.consumption x.distanceSinceLastFueling x.report.volume
                                                |> FuelReport.consumptionToFloat

                                        consumptionText =
                                            if consumption > 0 then
                                                consumption
                                                    |> String.fromFloat
                                                    |> roundString100

                                            else
                                                "-"
                                    in
                                    el (rowTextStyle ++ [ Font.alignRight ]) (text consumptionText)
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


viewFooter : Model -> Element Msg
viewFooter _ =
    none


fetchFuelHistory : Session -> Int -> Cmd Msg
fetchFuelHistory session bus_id =
    Api.get session (Endpoint.fuelReports bus_id) (list fuelRecordDecoder)
        |> Cmd.map (groupReports (Session.timeZone session) >> RecordsResponse)


groupReports :
    Time.Zone
    -> WebData (List FuelReport)
    -> WebData (List GroupedReports)
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
                (distancedReports
                    |> Utils.GroupBy.attr
                        { groupBy = .report >> .date >> Date.fromPosix timezone >> Date.format "yyyy MM"
                        , nameAs = .report >> .date >> Date.fromPosix timezone >> Date.format "MMM yyyy"
                        , reverse = True
                        }
                    |> List.reverse
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


tabBarItems : (Msg -> msg) -> List (TabBarItem msg)
tabBarItems mapper =
    [ TabBar.Button
        { title = "Add Fuel record"
        , icon = Icons.add
        , onPress = CreateFuelReport |> mapper
        }
    ]


roundString100 : String -> String
roundString100 =
    \c ->
        case List.head (String.indexes "." c) of
            Nothing ->
                c ++ ".00"

            Just location ->
                let
                    length =
                        String.length c
                in
                String.padRight (length + (2 - (length - location - 1))) '0' c
