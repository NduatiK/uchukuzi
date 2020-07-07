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
    , inEditMode : Bool
    , data : WebData Data
    , statistics : Maybe Statistics
    }


type alias Data =
    { groupedReports : List GroupedReports
    , numberOfStudents : Int
    , tripsMade : Int
    , statistics : Maybe Statistics
    }


{-| Statistics for all the reports
-}
type alias Statistics =
    { stdDev : Float
    , mean : Float
    }


type alias AnnotatedReport =
    { id : Int
    , cost : Int
    , date : Time.Posix
    , volume : Volume
    , cumulative :
        { distance : Distance
        , volume : Volume
        }
    , sinceLastReport :
        { distance : Distance
        }
    }


type alias GroupedReports =
    ( String, List AnnotatedReport )


init : Int -> Session -> ( Model, Cmd Msg )
init busID session =
    ( { session = session
      , busID = busID
      , data = Loading
      , statistics = Nothing
      , inEditMode = False
      }
    , fetchFuelHistory session busID
    )



-- UPDATE


type Msg
    = RecordsResponse (WebData ( Data, Cmd Msg ))
    | CreateFuelReport
    | Delete Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CreateFuelReport ->
            ( model, Navigation.rerouteTo model (Navigation.CreateFuelReport model.busID) )

        RecordsResponse response ->
            case response of
                Success ( data, cmd ) ->
                    ( { model | data = Success data }, cmd )

                Failure e ->
                    ( { model | data = Failure e }, Cmd.none )

                Loading ->
                    ( { model | data = Loading }, Cmd.none )

                NotAsked ->
                    ( { model | data = NotAsked }, Cmd.none )

        Delete id_ ->
            ( model, Cmd.none )



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
                    column [ Font.center, centerX, centerY, spacing 4 ]
                        [ el [ centerX ] (text "No fuel data available")
                        , el [ centerX ] (text "Click the button below ↓ to start tracking fuel purchases")
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
                |> List.map .cost
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
                , row [ width fill ]
                    (viewFuelTable reportsForDate timezone
                        :: (if model.inEditMode then
                                [ viewEditOptions reportsForDate ]

                            else
                                []
                           )
                    )
                ]
    in
    List.map viewGroup groupedReports


viewFuelTable : List AnnotatedReport -> Time.Zone -> Element Msg
viewFuelTable reportsForDate timezone =
    let
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
    in
    column
        [ spacing 12
        , height fill
        , width fill
        ]
        [ table
            [ spacingXY 30 15
            , paddingEach { edges | left = 10 }
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
                                    x.date |> Date.fromPosix timezone |> Date.format "MMM ddd"
                            in
                            rowTextAlign [ Font.alignLeft, alignLeft ] dateText
                  }
                , { header = tableHeader [ "FUEL VOLUME", "(L)" ] [ alignRight ]
                  , width = fill
                  , view =
                        \report ->
                            let
                                consumptionText =
                                    report.volume
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
                        \report ->
                            let
                                distanceText =
                                    if FuelReport.distanceToInt report.sinceLastReport.distance > 0 then
                                        String.fromInt (FuelReport.distanceToInt report.sinceLastReport.distance // 1000)

                                    else
                                        "-"
                            in
                            rowText distanceText
                  }
                , { header = tableHeader [ "FUEL CONSUMPTION", "(L/100KM)" ] [ alignRight ]
                  , width = fill
                  , view =
                        \report ->
                            let
                                consumption =
                                    FuelReport.consumption report.sinceLastReport.distance report.volume
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
                        \report ->
                            rowText (String.fromInt report.cost)
                  }
                ]
            }
        , column [ alignRight, spacing 4 ]
            [ el [ width fill, height (px 2), Background.color (rgb255 96 96 96) ] none
            , el (Font.alignRight :: Font.bold :: Style.tableElementStyle) (text ("KES. " ++ String.fromInt (totalForGroup reportsForDate)))
            ]
        ]


viewEditOptions : List AnnotatedReport -> Element Msg
viewEditOptions reportsForDate =
    let
        tableHeader strings attr =
            column (height fill :: Style.tableHeaderStyle)
                (List.map
                    (\x -> el attr (text (String.toUpper x)))
                    strings
                )
    in
    column
        [ spacing 12
        , height fill
        ]
        [ table
            [ spacingXY 30 15
            , paddingXY 10 0
            , Background.color Colors.transparent
            ]
            { data = reportsForDate
            , columns =
                [ { header = tableHeader [ " ", " " ] [ alignRight ]
                  , width = px 24
                  , view =
                        \report ->
                            StyledElement.iconButton [ padding 0, Background.color Colors.transparent, Colors.fillErrorRedHover, alpha 0.54, mouseOver [ alpha 1 ] ]
                                { icon = Icons.trash
                                , iconAttrs = [ alpha 1 ]
                                , onPress = Just (Delete report.id)
                                }
                  }
                ]
            }
        ]


viewFooter : Model -> Element Msg
viewFooter _ =
    none


fetchFuelHistory : Session -> Int -> Cmd Msg
fetchFuelHistory session bus_id =
    Api.get session (Endpoint.fuelReports bus_id) (decoder session)
        |> Cmd.map RecordsResponse


decoder : Session -> Json.Decode.Decoder ( Data, Cmd Msg )
decoder session =
    Json.Decode.succeed (\reports students -> groupReports (Session.timeZone session) reports students)
        |> required "reports" (list fuelRecordDecoder)
        |> required "students" int


groupReports :
    Time.Zone
    -> List FuelReport
    -> Int
    -> ( Data, Cmd Msg )
groupReports timezone reports students =
    let
        sortedReports : List FuelReport
        sortedReports =
            reports
                |> List.sortWith compareReports

        --The sortedReports with the distance travelled since last fueling information and
        -- total distance purchased at that point data
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
                        , { id = report.id
                          , cost = report.cost
                          , date = report.date
                          , volume = report.volume
                          , cumulative =
                                { distance = report.totalDistanceCovered
                                , volume = totalFuelConsumed
                                }
                          , sinceLastReport =
                                { distance = distanceSinceLastFueling
                                }
                          }
                            :: acc
                        )
                    )
                    ( ( FuelReport.distance 0, FuelReport.volume 0 ), [] )
                |> Tuple.second

        --The Months and the Days within them are listed Recent to Oldest
        groupedReports =
            distancedReports
                |> Utils.GroupBy.attr
                    { groupBy = .date >> Date.fromPosix timezone >> Date.format "yyyy MM" -- Order by year number then month number
                    , nameAs = .date >> Date.fromPosix timezone >> Date.format "MMM yyyy"
                    , ascending = False -- Reverse naming order ie descending
                    }
                |> List.reverse

        tripsMade =
            reports
                |> List.map .tripsMade
                |> List.maximum
                |> Maybe.withDefault 0

        runningAverage report =
            FuelReport.consumption report.cumulative.distance report.cumulative.volume

        consumptionOnDate : AnnotatedReport -> FuelReport.ConsumptionRate
        consumptionOnDate report =
            FuelReport.consumption report.sinceLastReport.distance report.volume

        statistics =
            let
                stdDev =
                    Statistics.deviation
                        (distancedReports
                            |> List.map consumptionOnDate
                            |> List.map FuelReport.consumptionToFloat
                            |> List.filter (\x -> x /= 0)
                        )

                mean =
                    distancedReports
                        |> takeLast
                        |> Maybe.map runningAverage
                        |> Maybe.map FuelReport.consumptionToFloat
            in
            case ( stdDev, mean ) of
                ( Just stdDev_, Just mean_ ) ->
                    Just
                        { stdDev = stdDev_
                        , mean = mean_
                        }

                _ ->
                    Nothing

        takeLast list =
            list
                |> List.drop (List.length list - 1)
                |> List.head

        plotData =
            distancedReports
                |> List.filter (\x -> FuelReport.distanceToInt x.sinceLastReport.distance /= 0)

        cmd =
            Ports.renderChart
                { x =
                    plotData
                        |> List.map (.date >> Time.posixToMillis)
                , y =
                    { consumptionOnDate =
                        plotData
                            |> List.map (consumptionOnDate >> FuelReport.consumptionToFloat)
                    , runningAverage =
                        plotData
                            |> List.map (runningAverage >> FuelReport.consumptionToFloat)
                    }
                , statistics = statistics
                }
    in
    ( { groupedReports = groupedReports
      , numberOfStudents = students
      , tripsMade = tripsMade
      , statistics = statistics
      }
    , cmd
    )


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
            (\x acc -> acc + (x |> .cost))
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
