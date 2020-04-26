module Pages.Buses.Bus.FuelHistoryPage exposing (Model, Msg, init, update, view, viewButtons, viewFooter)

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
import Models.FuelReport exposing (FuelReport, fuelRecordDecoder)
import Navigation
import RemoteData exposing (..)
import Session exposing (Session)
import Statistics
import Style exposing (edges)
import StyledElement
import StyledElement.Footer as Footer
import StyledElement.Graph
import Task
import Time
import Utils.GroupBy


type alias Model =
    { session : Session
    , busID : Int
    , currentPage : Page
    , reports : WebData (List GroupedReports)
    , statistics :
        Maybe
            { stdDev : Float
            , mean : Float
            }
    , chartData :
        Maybe
            { data : List ( Time.Posix, Float )
            , month : String
            }
    }


type alias Distance =
    Int


type alias GroupedReports =
    ( String, List ( FuelReport, Distance ) )


type Page
    = Summary
    | ConsumptionSpikes


pageToString page =
    case page of
        Summary ->
            "Summary"

        ConsumptionSpikes ->
            "Consumption Spikes"


init : Int -> Session -> ( Model, Cmd Msg )
init busID session =
    ( { session = session
      , busID = busID
      , currentPage = Summary
      , reports = Loading
      , chartData = Nothing
      , statistics = Nothing
      }
    , fetchFuelHistory session busID
    )



-- UPDATE


type Msg
    = ClickedSummaryPage
      --------------------
    | ClickedConsumptionSpikesPage
    | RecordsResponse (WebData ( List ( FuelReport, Distance ), List GroupedReports ))
      -- | Show (GroupedReports)
    | Show String
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    -- let
    --     chartData =
    --         model.chartData
    -- in
    case msg of
        Show month ->
            case model.reports of
                Success reports ->
                    let
                        matching =
                            List.head (List.filter (Tuple.first >> (\x -> x == month)) reports)
                    in
                    case matching of
                        Just match ->
                            ( { model
                                | chartData =
                                    Just
                                        { month = month
                                        , data =
                                            List.map
                                                (\( report, distance ) ->
                                                    if report.volume > 0 then
                                                        ( report.date, toFloat distance / report.volume / 1000 )

                                                    else
                                                        ( report.date, 0 )
                                                )
                                                (Tuple.second match)
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

        ClickedSummaryPage ->
            ( { model | currentPage = Summary }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )

        ClickedConsumptionSpikesPage ->
            ( { model | currentPage = ConsumptionSpikes }, Cmd.none )

        RecordsResponse response ->
            case response of
                Success ( distanced, grouped ) ->
                    let
                        ( chartData, statistics ) =
                            case List.head grouped of
                                Just head ->
                                    let
                                        data =
                                            List.map
                                                (\( report, distance ) ->
                                                    if report.volume > 0 then
                                                        ( report.date, toFloat distance / report.volume / 1000 )

                                                    else
                                                        ( report.date, 0 )
                                                )
                                                (Tuple.second head)

                                        fuelConsuptions =
                                            List.map Tuple.second data

                                        stdDev =
                                            Statistics.deviation fuelConsuptions

                                        mean =
                                            List.foldl (+) 0 fuelConsuptions / toFloat (List.length fuelConsuptions)
                                    in
                                    ( Just
                                        { month = Tuple.first head
                                        , data = data
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
        , Style.clipStyle
        , Border.solid
        , htmlAttribute (id "view")
        , htmlAttribute (Html.Attributes.style "scroll-behavior" "smooth")
        , Style.animatesAll
        ]
        [ viewGraph model
        , case model.reports of
            Success reports ->
                column []
                    [ --     row (Style.header2Style ++ [ alignLeft, width fill, Font.color Colors.black, spacing 30 ])
                      --     [ text "Total Paid"
                      --     , el [ Font.size 21, Font.color Colors.darkGreen ] (text ("KES. " ++ String.fromInt (totalCost reports)))
                      --     ]
                      -- ,
                      viewGroupedReports model reports
                    ]

            Failure reports ->
                el (centerX :: centerY :: Style.labelStyle) (paragraph [] [ text "Something went wrong, please reload the page" ])

            _ ->
                Icons.loading [ centerX, centerY, width (px 46), height (px 46) ]

        -- , wrappedRow [] []
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
                (StyledElement.Graph.view
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
            Maybe.andThen (.month >> Just) model.chartData

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
                                \( report, _ ) ->
                                    let
                                        dateText =
                                            report.date |> Date.fromPosix timezone |> Date.format "MMM ddd"
                                    in
                                    el rowTextStyle (text dateText)
                          }
                        , { header = tableHeader [ "FUEL CONSUMPTION", "(KM/L)" ] [ alignRight ]
                          , width = fill
                          , view =
                                \( report, distance ) ->
                                    let
                                        consumptionText =
                                            String.fromFloat (round100 (Basics.toFloat distance / (report.volume * 1000)))
                                    in
                                    el rowTextStyle (text consumptionText)
                          }
                        , { header =
                                column (alignRight :: Style.tableHeaderStyle)
                                    [ el [ alignRight ] (text (String.toUpper "DISTANCE "))
                                    , el [ alignRight ] (text (String.toUpper "TRAVELLED (KM)"))
                                    ]
                          , width = fill
                          , view =
                                \( report, distance ) ->
                                    let
                                        distanceText =
                                            if distance > 0 then
                                                String.fromInt (distance // 1000)

                                            else
                                                "-"
                                    in
                                    el (width fill :: Font.alignRight :: rowTextStyle) (text distanceText)
                          }
                        , { header = tableHeader [ "FUEL COST", "(KES)" ] [ alignRight ]
                          , width = fill
                          , view =
                                \( report, distance ) ->
                                    el (width fill :: Font.alignRight :: rowTextStyle) (text (String.fromInt report.cost))
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
        (StyledElement.buttonLink [ centerX, Border.width 3, Border.color Colors.purple, Background.color Colors.white ]
            { label =
                row []
                    [ Icons.add [ Colors.fillPurple, centerY ]
                    , el [ centerY, Font.color Colors.purple ] (text "Add Fuel record")
                    ]
            , route = Navigation.CreateFuelReport model.busID
            }
        )


viewFooter : Model -> Element Msg
viewFooter model =
    Footer.coloredView model.currentPage
        pageToString
        [ { page = Summary, body = "", action = ClickedSummaryPage, highlightColor = Colors.darkGreen }
        , { page = ConsumptionSpikes, body = "3", action = ClickedConsumptionSpikesPage, highlightColor = Colors.errorRed }
        ]


fetchFuelHistory : Session -> Int -> Cmd Msg
fetchFuelHistory session bus_id =
    Api.get session (Endpoint.fuelReports bus_id) (list fuelRecordDecoder)
        |> Cmd.map (groupReports (Session.timeZone session) >> RecordsResponse)


groupReports : Time.Zone -> WebData (List FuelReport) -> WebData ( List ( FuelReport, Distance ), List GroupedReports )
groupReports timezone reports_ =
    case reports_ of
        Success reports ->
            let
                sortedReports : List FuelReport
                sortedReports =
                    List.sortWith compareReports reports

                distancedReports : List ( FuelReport, Distance )
                distancedReports =
                    Tuple.second
                        (List.foldl
                            (\report ( totalDistance, acc ) ->
                                ( report.distance_covered
                                , ( report, report.distance_covered - totalDistance ) :: acc
                                )
                            )
                            ( 0, [] )
                            sortedReports
                        )
            in
            Success
                ( distancedReports
                , Utils.GroupBy.attr
                    { groupBy = Tuple.first >> .date >> Date.fromPosix timezone >> Date.format "yyyy MM"
                    , nameAs = Tuple.first >> .date >> Date.fromPosix timezone >> Date.format "MMM yyyy"
                    , reverse = False
                    }
                    distancedReports
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
    in
    case ( compare (getDate report1) (getDate report2), compare report1.distance_covered report2.distance_covered ) of
        ( GT, _ ) ->
            GT

        ( LT, _ ) ->
            LT

        ( _, x ) ->
            x


round100 : Float -> Float
round100 float =
    toFloat (round (float * 100)) / 100


totalForGroup group =
    List.foldl (\x y -> y + (Tuple.first >> .cost) x) 0 group
