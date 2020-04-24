module Pages.Buses.Bus.BusRepairsPage exposing (Model, Msg, init, update, view, viewFooter)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events exposing (onMouseEnter, onMouseLeave)
import Element.Font as Font
import Icons
import Icons.Repairs
import Models.Bus exposing (Part(..), Repair)
import Navigation
import RemoteData exposing (..)
import Style
import StyledElement
import StyledElement.Footer as Footer
import Time
import Utils.GroupBy


type alias Model =
    { busID : Int
    , repairs : List Repair
    , timezone : Time.Zone
    , groupedRepairs : List GroupedRepairs
    , currentPage : Page
    , highlightedRepair : Maybe Repair
    }


type alias GroupedRepairs =
    ( String, List Repair )


type Page
    = Summary
      -- | ScheduledRepairs
    | PastRepairs


pageToString : Page -> String
pageToString page =
    case page of
        Summary ->
            "Summary"

        -- ScheduledRepairs ->
        --     "Scheduled Repairs"
        PastRepairs ->
            "Past Repairs"


type Msg
    = ClickedSummaryPage
      --------------------
      -- | ClickedScheduledRepairsPage
    | ClickedPastRepairsPage
      --------------------
    | HoveredOver (Maybe Repair)


init : Int -> List Repair -> Time.Zone -> ( Model, Cmd Msg )
init busID repairs timezone =
    ( { busID = busID
      , repairs = repairs
      , currentPage = PastRepairs
      , timezone = timezone
      , groupedRepairs = groupRepairs repairs timezone
      , highlightedRepair = Nothing
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedSummaryPage ->
            ( { model | currentPage = Summary }, Cmd.none )

        -- ClickedScheduledRepairsPage ->
        --     ( { model | currentPage = ScheduledRepairs }, Cmd.none )
        ClickedPastRepairsPage ->
            ( { model | currentPage = PastRepairs }, Cmd.none )

        HoveredOver repair ->
            ( { model | highlightedRepair = repair }, Cmd.none )



-- VIEW


view : Model -> Int -> Element Msg
view model height =
    case model.currentPage of
        Summary ->
            viewSummary model (height - 220)

        _ ->
            viewPastRepairs model (height - 220)


viewSummary : Model -> Int -> Element Msg
viewSummary model viewHeight =
    let
        totalCost =
            List.foldl (\x y -> y + x.cost) 0 model.repairs
    in
    column [ height (px viewHeight), width (px 500), paddingXY 40 40 ]
        [ StyledElement.textStack "Due for maintenance in" "300km"
        , StyledElement.textStack "Total Paid for Repairs" ("KES. " ++ String.fromInt totalCost)
        ]


viewPastRepairs : Model -> Int -> Element Msg
viewPastRepairs model viewHeight =
    row
        [ height (px viewHeight)
        , width fill
        , Style.clipStyle
        , spacing 20
        ]
        [ viewGroupedRepairs model
        , el [ centerX, width (px 2), height (fill |> maximum 500), Background.color Colors.darkness ] none
        , column [ height fill, width (fillPortion 1) ]
            [ StyledElement.buttonLink [ centerX, Border.width 3, Border.color Colors.purple, Background.color Colors.white ]
                { label =
                    row []
                        [ Icons.add [ Colors.fillPurple, centerY ]
                        , el [ centerY, Font.color Colors.purple ] (text "Add Repair record")
                        ]
                , route = Navigation.CreateBusRepair model.busID
                }
            , viewVehicle model
            ]
        ]


viewGroupedRepairs { groupedRepairs, repairs } =
    let
        totalCost =
            List.foldl (\x y -> y + x.cost) 0 repairs

        viewGroup ( date, repairsForDate ) =
            let
                totalCostForDate =
                    List.foldl (\x y -> y + x.cost) 0 repairsForDate
            in
            column [ spacing 10, height fill, width fill ]
                [ el Style.header2Style (text (date ++ " - KES. " ++ String.fromInt totalCostForDate))
                , wrappedRow [ spacing 10, width (fill |> maximum 800) ] (List.map viewRepair repairsForDate)
                ]
    in
    column [ scrollbarY, height fill, width (fillPortion 2) ]
        (column [ paddingXY 0 10 ]
            [ row (Style.header2Style ++ [ alignLeft, width fill, Font.color Colors.black, spacing 30 ])
                [ text "Total Paid for Repairs"
                , el [ Font.size 21, Font.color Colors.darkGreen ] (text ("KES. " ++ String.fromInt totalCost))
                ]
            , el [ height (px 1), Background.color Colors.simpleGrey, width fill ] none
            ]
            :: List.map viewGroup groupedRepairs
        )


viewRepair repair =
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
    in
    row
        [ height (px 64)
        , width (fillPortion 1 |> minimum 200)
        , spacing 8
        , paddingXY 12 11
        , Border.color (Colors.withAlpha Colors.darkness 0.3)
        , Border.solid
        , Border.width 1
        , onMouseEnter (HoveredOver (Just repair))
        , onMouseLeave (HoveredOver Nothing)
        , Style.animatesShadow
        ]
        [ el [ width (px 3), height fill, Background.color Colors.darkGreen ] none
        , column [ spacing 8 ]
            [ el routeStyle (text (Models.Bus.titleForPart repair.part))
            , el timeStyle (text ("KES." ++ String.fromInt repair.cost))
            ]
        ]


viewVehicle model =
    let
        viewImage part =
            case model.highlightedRepair of
                Just repair ->
                    if repair.part == part then
                        inFront (Models.Bus.imageForPart part [])

                    else
                        moveUp 0

                Nothing ->
                    moveUp 0
    in
    column [ height fill, padding 10, width fill ]
        [ Icons.Repairs.chassis
            [ scale 0.8
            , centerX
            , viewImage VerticalAxis
            , inFront (Icons.Repairs.engine [])
            , viewImage Engine

            --
            , viewImage FrontLeftTire
            , viewImage FrontRightTire

            --
            , viewImage RearLeftTire
            , viewImage RearRightTire

            --
            , viewImage FrontCrossAxis
            , viewImage RearCrossAxis
            ]
        , paragraph (Style.labelStyle ++ [ width fill ])
            [ case model.highlightedRepair of
                Nothing ->
                    none

                Just repair ->
                    text repair.description
            ]
        ]


viewFooter : Model -> Element Msg
viewFooter model =
    row [ width fill ]
        [ el [ width (fillPortion 2) ]
            (Footer.view model.currentPage
                pageToString
                [ -- ( Summary, "", ClickedSummaryPage )
                  -- ,
                  ( PastRepairs, String.fromInt (List.length model.repairs), ClickedPastRepairsPage )
                ]
            )
        , el [ width (fillPortion 1) ] none
        ]


groupRepairs : List Repair -> Time.Zone -> List ( String, List Repair )
groupRepairs trips timezone =
    Utils.GroupBy.date timezone .dateTime trips
