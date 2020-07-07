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
import Json.Decode exposing (int, list)
import Json.Decode.Pipeline exposing (required)
import Layout.TabBar as TabBar exposing (TabBarItem(..))
import Models.FuelReport as FuelReport exposing (Distance, FuelReport, Volume, fuelRecordDecoder)
import Navigation
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Statistics
import Style exposing (edges)
import StyledElement
import StyledElement.WebDataView as WebDataView
import Time
import Utils.GroupBy


type alias Model =
    { session : Session
    , busID : Int
    , data : WebData Data
    , statistics : Maybe Statistics
    }


type alias Data =
    { groupedReports : List GroupedReports
    , numberOfStudents : Int
    , tripsMade : Int
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
      , data = Loading
      , statistics = Nothing
      }
    , fetchFuelHistory session busID
    )



-- UPDATE


type Msg
    = RecordsResponse (WebData Data)
    | CreateFuelReport


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CreateFuelReport ->
            ( model, Navigation.rerouteTo model (Navigation.CreateFuelReport model.busID) )

        RecordsResponse response ->
            case response of
                Success { groupedReports, numberOfStudents, tripsMade } ->
                    let
                        reports =
                            groupedReports
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
                            Statistics.deviation (fuelConsumptions |> List.filter (\x -> x /= 0))

                        mean =
                            data
                                |> List.drop (List.length data - 1)
                                |> List.head
                                |> Maybe.map
                                    (\x ->
                                        x.runningAverage
                                            |> FuelReport.consumptionToFloat
                                    )

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
                                ( Just stdDev_, Just mean_ ) ->
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
                        | data =
                            Success
                                { groupedReports = groupedReports
                                , numberOfStudents = numberOfStudents
                                , tripsMade = tripsMade
                                }
                        , statistics = statistics
                      }
                      -- , Cmd.none
                    , cmd
                    )

                Failure e ->
                    ( { model | data = Failure e }, Cmd.none )

                Loading ->
                    ( { model | data = Loading }, Cmd.none )

                NotAsked ->
                    ( { model | data = NotAsked }, Cmd.none )



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    column
        [ height (px viewHeight)
        , width fill
        , clip
        , scrollbarY
        , Background.color Colors.backgroundGray
        , htmlAttribute (id "view")
        , htmlAttribute (Html.Attributes.style "scroll-behavior" "smooth")
        , Style.animatesAll
        ]
        [ WebDataView.view model.data
            (\data ->
                let
                    reports =
                        data.groupedReports
                in
                if reports == [] then
                    column [ width fill, centerX, centerY, spacing 4 ]
                        [ text "No fuel data available"
                        , text "Click the button below ↓ to start tracking fuel purchases"
                        ]

                else
                    row [ width fill, height fill ]
                        [ column [ width fill, height fill ]
                            [ viewGraph
                            , column
                                [ height fill
                                , paddingXY 0 20
                                , spacing 20
                                , centerX
                                ]
                                (viewStats data
                                    :: viewGroupedReports model reports
                                )
                            ]
                        , el [ width (px 36) ] none
                        ]
            )
        ]


viewGraph : Element msg
viewGraph =
    el [ width fill, height (px 350), Style.id "chart", paddingXY 20 0 ] none


viewStats : Data -> Element msg
viewStats data =
    let
        cost =
            data.groupedReports
                |> List.map Tuple.second
                |> List.concat
                |> List.map (.report >> .cost)
                |> List.sum

        tripCost () =
            cost // data.tripsMade

        currency value =
            "KES. " ++ String.fromInt value
    in
    row
        [ width fill
        , height fill
        , Background.color Colors.white
        , paddingXY 20 10
        , Border.color Colors.sassyGrey
        , Border.width 2
        , spaceEvenly
        ]
        (if data.tripsMade > 0 then
            [ el [ width (fillPortion 3), height fill ] (StyledElement.textStackWithColor "Fuel Cost Per Trip" (currency (tripCost ())) Colors.purple)
            , el [ width (fillPortion 1), height fill ] (el [ centerX, width (px 2), height fill, Background.color Colors.sassyGrey ] none)
            , el [ width (fillPortion 2), height fill ] (StyledElement.textStackWithColor "No. of Students" (String.fromInt data.numberOfStudents) Colors.purple)
            , el [ width (fillPortion 1), height fill ] (el [ centerX, width (px 2), height fill, Background.color Colors.sassyGrey ] none)
            , el [ width (fillPortion 3), height fill ] (StyledElement.textStackWithColor "Student Cost per Trip" (currency (tripCost () // data.numberOfStudents)) Colors.purple)
            ]

         else
            [ el [ width (fillPortion 3), height fill ] (StyledElement.textStackWithColor "Total" (currency cost) Colors.purple)
            , el [ width (fillPortion 1), height fill ] (el [ centerX, width (px 2), height fill, Background.color Colors.sassyGrey ] none)
            , el [ width (fillPortion 2), height fill ] (StyledElement.textStackWithColor "No. of Students" (String.fromInt data.numberOfStudents) Colors.purple)
            ]
        )


viewGroupedReports : Model -> List GroupedReports -> List (Element Msg)
viewGroupedReports model groupedReports =
    let
        timezone =
            Session.timeZone model.session

        tableHeader strings attr =
            column (height fill :: Style.tableHeaderStyle)
                (List.map
                    (\x -> el attr (text (String.toUpper x)))
                    strings
                )

        rowText : String -> Element Msg
        rowText =
            rowTextAlign [ Font.alignRight, alignRight ]

        rowTextAlign alignments =
            text
                >> el (Style.nonClickThrough :: Style.tableElementStyle ++ alignments)
                >> el [ Style.clickThrough ]

        hoverEl _ =
            el
                [ mouseOver [ Background.color Colors.darkGreen ]
                , height (px 33)
                , paddingXY 0 4
                , width fill
                , alpha 0.2
                ]
                none

        viewGroup : ( String, List AnnotatedReport ) -> Element Msg
        viewGroup ( month, reportsForDate ) =
            column
                [ spacing 12
                , height fill
                , centerX
                , Background.color Colors.white
                , paddingXY 28 20
                , Border.color Colors.sassyGrey
                , Border.width 2
                ]
                [ el
                    (Style.header2Style
                        ++ [ moveRight 10
                           , paddingXY 0 4
                           , Border.widthEach { edges | bottom = 2 }
                           , Border.color (Colors.withAlpha Colors.darkness 0.3)
                           ]
                    )
                    (text month)
                , table
                    [ spacingXY 30 15
                    , paddingXY 10 0
                    , Background.color Colors.transparent
                    , inFront
                        (column [ paddingEach { edges | top = 36 }, spacingXY 30 0, width fill ] (List.map hoverEl (List.range 0 (List.length reportsForDate - 1))))
                    ]
                    { data = reportsForDate
                    , columns =
                        [ { header = tableHeader [ "DATE" ] [ alignBottom ]
                          , width = fill |> maximum 100
                          , view =
                                \x ->
                                    let
                                        dateText =
                                            x.report.date |> Date.fromPosix timezone |> Date.format "MMM ddd"
                                    in
                                    rowTextAlign [ Font.alignLeft, alignLeft ] dateText
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
                                    rowText consumptionText
                          }
                        , { header =
                                tableHeader [ "DISTANCE ", "TRAVELLED (KM)" ] [ alignRight ]
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
                                    rowText distanceText
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
                                    rowText consumptionText
                          }
                        , { header = tableHeader [ "FUEL COST", "(KES)" ] [ alignRight ]
                          , width = fill
                          , view =
                                \x ->
                                    rowText (String.fromInt x.report.cost)
                          }
                        ]
                    }
                , column [ alignRight, spacing 4 ]
                    [ el [ width fill, height (px 2), Background.color (rgb255 96 96 96) ] none
                    , el (Font.alignRight :: Font.bold :: Style.tableElementStyle) (text ("KES. " ++ String.fromInt (totalForGroup reportsForDate)))
                    ]
                ]
    in
    List.map viewGroup groupedReports


viewFooter : Model -> Element Msg
viewFooter _ =
    none


fetchFuelHistory : Session -> Int -> Cmd Msg
fetchFuelHistory session bus_id =
    Api.get session (Endpoint.fuelReports bus_id) (decoder session)
        |> Cmd.map RecordsResponse


decoder : Session -> Json.Decode.Decoder Data
decoder session =
    Json.Decode.succeed (\reports students -> groupReports (Session.timeZone session) reports students)
        |> required "reports" (list fuelRecordDecoder)
        |> required "students" int


groupReports :
    Time.Zone
    -> List FuelReport
    -> Int
    -> Data
groupReports timezone reports students =
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

        tripsMade =
            reports
                |> List.map .tripsMade
                |> List.maximum
                |> Maybe.withDefault 0
    in
    { groupedReports =
        distancedReports
            |> Utils.GroupBy.attr
                { groupBy = .report >> .date >> Date.fromPosix timezone >> Date.format "yyyy MM"
                , nameAs = .report >> .date >> Date.fromPosix timezone >> Date.format "MMM yyyy"
                , reverse = True
                }
            |> List.reverse
    , numberOfStudents = students
    , tripsMade = tripsMade
    }


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
