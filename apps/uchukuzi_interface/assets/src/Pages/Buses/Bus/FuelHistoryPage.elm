module Pages.Buses.Bus.FuelHistoryPage exposing (Model, Msg, init, update, view, viewButtons, viewFooter)

import Api
import Api.Endpoint as Endpoint
import Colors
import Date
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Icons
import Json.Decode as Decode exposing (Decoder, int, list, string)
import Models.FuelReport exposing (FuelReport, fuelRecordDecoder)
import Navigation
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import StyledElement.Footer as Footer
import Time
import Utils.GroupBy


type alias Model =
    { session : Session
    , busID : Int
    , currentPage : Page
    , reports : WebData (List GroupedReports)
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
      }
    , fetchFuelHistory session busID
    )



-- UPDATE


type Msg
    = ClickedSummaryPage
      --------------------
    | ClickedConsumptionSpikesPage
    | RecordsResponse (WebData (List GroupedReports))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedSummaryPage ->
            ( { model | currentPage = Summary }, Cmd.none )

        ClickedConsumptionSpikesPage ->
            ( { model | currentPage = ConsumptionSpikes }, Cmd.none )

        RecordsResponse response ->
            ( { model | reports = response }, Cmd.none )



-- VIEW


view : Model -> Element Msg
view model =
    let
        totalForGroup group =
            List.foldl (\x y -> y + (Tuple.first >> .cost) x) 0 group

        totalCost =
            List.foldl (\x y -> y + totalForGroup (Tuple.second x)) 0
    in
    column
        [ height fill
        , width fill
        , Style.clipStyle
        , Border.solid
        ]
        [ viewGraph model
        , case model.reports of
            Success reports ->
                column []
                    [ row (Style.header2Style ++ [ alignLeft, width fill, Font.color Colors.black, spacing 30 ])
                        [ text "Total Paid"
                        , el [ Font.size 21, Font.color Colors.darkGreen ] (text ("KES. " ++ String.fromInt (totalCost reports)))
                        ]
                    , viewGroupedReports reports
                    ]

            Failure reports ->
                el (centerX :: centerY :: Style.labelStyle) (paragraph [] [ text "Something went wrong, please reload the page" ])

            _ ->
                Icons.loading [ centerX, centerY, width (px 46), height (px 46) ]

        -- , wrappedRow [] []
        ]


viewGraph : Model -> Element Msg
viewGraph model =
    el [ width fill, height (px 500) ] none


viewGroupedReports : List GroupedReports -> Element Msg
viewGroupedReports groupedReports =
    let
        viewGroup ( month, reportsForDate ) =
            column [ spacing 0, height fill, width fill ]
                [ el (Style.header2Style ++ [ padding 0, Font.light ]) (text month)
                , wrappedRow
                    [ spacing 10
                    , width (fill |> maximum 800)
                    , paddingEach { edges | top = 10, right = 10 }
                    ]
                    (List.map viewReport reportsForDate)
                ]
    in
    column [ scrollbarY, height fill, width (fillPortion 2), paddingXY 0 10 ]
        (List.map viewGroup groupedReports)


viewReport ( report, distance ) =
    let
        timeStyle =
            Style.defaultFontFace
                ++ [ Font.color Colors.darkText
                   , Font.size 14
                   , Font.bold
                   ]

        routeStyle =
            Style.defaultFontFace
                ++ [ Font.color (rgb255 85 88 98)
                   , Font.size 14
                   ]
    in
    column []
        [ el (padding 4 :: routeStyle) (text (Date.format "MMM ddd" report.date))
        , column
            [ width (fillPortion 1 |> minimum 200)
            , Border.color (Colors.withAlpha Colors.darkness 0.3)
            , Border.solid
            , Border.width 1

            -- , onMouseEnter (HoveredOver (Just report))
            -- , onMouseLeave (HoveredOver Nothing)
            , Style.animatesShadow
            ]
            [ row [ spacing 8, paddingXY 12 11 ]
                (if distance > 0 then
                    [ el [ padding 12 ] (text (String.fromFloat (round100 (Basics.toFloat distance / (report.volume * 1000))) ++ "KPL"))
                    , el [ width (px 1), height fill, Background.color (Colors.withAlpha Colors.darkness 0.3) ] none
                    , paragraph timeStyle [ text (String.fromInt (distance // 1000) ++ "km travelled") ]

                    -- , el timeStyle (text ("KES." ++ String.fromInt report.cost))
                    ]

                 else
                    [ el [] (text (Date.format "MMM ddd" report.date))
                    ]
                )
            , el [ height (px 1), width fill, Background.color (Colors.withAlpha Colors.darkness 0.3) ] none
            , row [ spacing 8, paddingXY 12 11 ]
                [ el [] (text ("KES." ++ String.fromInt report.cost))
                ]
            ]
        ]


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
    Api.get session (Endpoint.fuelReports bus_id) (list (fuelRecordDecoder (Session.timeZone session)))
        |> Cmd.map (groupReports >> RecordsResponse)


groupReports : WebData (List FuelReport) -> WebData (List GroupedReports)
groupReports reports_ =
    case reports_ of
        Success reports ->
            let
                sortedReports : List ( FuelReport, Distance )
                sortedReports =
                    Tuple.second
                        (List.foldl
                            (\report ( totalDistance, acc ) ->
                                ( report.distance_covered
                                , ( report, report.distance_covered - totalDistance ) :: acc
                                )
                            )
                            ( 0, [] )
                            (List.sortWith compareReports reports)
                        )
            in
            Success
                (Utils.GroupBy.attr
                    { groupBy = Tuple.first >> .date >> Date.format "yyyy MM"
                    , nameAs = Tuple.first >> .date >> Date.format "MMM yyyy"
                    , reverse = False
                    }
                    sortedReports
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
            .date >> Date.format "yyyy MM"
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
