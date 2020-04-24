module Pages.Buses.Bus.FuelHistoryPage exposing (Model, Msg, init, update, view, viewFooter)

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Icons
import Navigation
import RemoteData exposing (..)
import Style exposing (edges)
import StyledElement
import StyledElement.Footer as Footer
import Time


type alias Model =
    { busID : Int
    , currentPage : Page
    }


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
    ( { busID = bus.id
      , currentPage = Summary
      }
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
        [ height fill
        , width fill
        , Style.clipStyle
        , Border.solid

        -- , Border.color (rgb255 197 197 197)
        -- , Border.width 1
        -- , clip
        -- , Background.color (rgba 0 0 0 0.05)
        ]
        (el
            [ alignRight ]
            (StyledElement.buttonLink [ centerX, Border.width 3, Border.color Colors.purple, Background.color Colors.white ]
                { label =
                    row []
                        [ Icons.add [ Colors.fillPurple, centerY ]
                        , el [ centerY, Font.color Colors.purple ] (text "Add Fuel record")
                        ]
                , route = Navigation.CreateFuelRecord model.busID
                }
            )
        )


viewFooter : Model -> Element Msg
viewFooter model =
    Footer.coloredView model.currentPage
        pageToString
        [ { page = Summary, body = "", action = ClickedSummaryPage, highlightColor = Colors.darkGreen }
        , { page = ConsumptionSpikes, body = "3", action = ClickedConsumptionSpikesPage, highlightColor = Colors.errorRed }
        ]
