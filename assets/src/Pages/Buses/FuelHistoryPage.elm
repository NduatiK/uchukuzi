module Pages.Buses.FuelHistoryPage exposing (Model, Msg, init, update, view, viewFooter)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import RemoteData exposing (..)
import Style exposing (edges)
import StyledElement.Footer as Footer
import Time


type alias Model =
    { currentPage : Page }


type Page
    = Summary
    | ConsumptionSpikes


pageToString page =
    case page of
        Summary ->
            "Summary"

        ConsumptionSpikes ->
            "Consumption Spikes"


type Msg
    = ClickedSummaryPage
      --------------------
    | ClickedConsumptionSpikesPage


init : { bus | id : Int } -> Time.Zone -> ( Model, Cmd Msg )
init bus timezone =
    ( Model Summary
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickedSummaryPage ->
            ( { model | currentPage = Summary }, Cmd.none )

        ClickedConsumptionSpikesPage ->
            ( { model | currentPage = ConsumptionSpikes }, Cmd.none )



-- VIEW


view : Model -> Element msg
view model =
    el
        [ height (px 10)
        , width fill
        , Style.clipStyle
        , Border.solid
        , Border.color (rgb255 197 197 197)
        , Border.width 1
        , clip
        , Background.color (rgba 0 0 0 0.05)
        ]
        (el
            []
            none
        )


viewFooter : Model -> Element Msg
viewFooter model =
    Footer.coloredView model.currentPage
        pageToString
        [ { page = Summary, body = "", action = ClickedSummaryPage, highlightColor = Colors.darkGreen }
        , { page = ConsumptionSpikes, body = "3", action = ClickedConsumptionSpikesPage, highlightColor = Colors.errorRed }
        ]
