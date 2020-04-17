module Pages.Buses.BusRepairsPage exposing (Model, Msg, init, update, view, viewFooter)

import Api exposing (get)
import Api.Endpoint as Endpoint exposing (trips)
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Html.Attributes exposing (class, id)
import Icons
import Icons.Repairs
import Iso8601
import Json.Decode as Decode exposing (Decoder, float, int, list, string)
import Json.Decode.Pipeline exposing (optional, required, resolve)
import Models.Bus exposing (RepairRecord)
import Navigation
import Ports
import RemoteData exposing (..)
import Style exposing (edges)
import StyledElement
import StyledElement.Footer as Footer
import Time
import Utils.DateFormatter


type alias Model =
    { busID : Int
    , repairs : List RepairRecord
    , currentPage : Page
    }


type Page
    = Summary
      -- | ScheduledRepairs
    | PastRepairs


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
      --------------------
    | ClickedPastRepairsPage


init : Int -> List RepairRecord -> ( Model, Cmd Msg )
init busID repairs =
    ( { busID = busID
      , repairs = repairs
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

        -- ClickedScheduledRepairsPage ->
        --     ( { model | currentPage = ScheduledRepairs }, Cmd.none )
        ClickedPastRepairsPage ->
            ( { model | currentPage = PastRepairs }, Cmd.none )



-- VIEW


view : Model -> Element Msg
view model =
    case model.currentPage of
        Summary ->
            viewSummary model

        _ ->
            viewPastRepairs model


viewSummary : Model -> Element msg
viewSummary model =
    let
        totalCost =
            List.foldl (\x y -> y + x.cost) 0 model.repairs
    in
    column [ height fill, width (px 500), paddingXY 40 40 ]
        [ StyledElement.textStack "Due for maintenance in" "300km"
        , StyledElement.textStack "Total Paid for Repairs" ("KES. " ++ String.fromInt totalCost)
        ]


viewPastRepairs : Model -> Element msg
viewPastRepairs model =
    el
        [ height fill
        , width fill
        , Style.clipStyle
        ]
        (row []
            [ StyledElement.buttonLink []
                { label =
                    row []
                        [ Icons.add [ Colors.fillWhite, centerY ]
                        , el [ centerY ] (text "Add")
                        ]
                , route = Navigation.CreateBusRepair model.busID
                }
            ]
        )


viewVehicle model =
    let
        viewImage image visible =
            if visible then
                inFront image

            else
                moveUp 0
    in
    el [ alignRight, height fill, padding 40 ]
        (Icons.Repairs.chassis
            [ centerY
            , centerX
            , viewImage (Icons.Repairs.verticalAxisRepair []) True
            , inFront (Icons.Repairs.engine [])
            , viewImage (Icons.Repairs.engineRepair []) True

            --
            , viewImage (Icons.Repairs.frontLeftTireRepair []) True
            , viewImage (Icons.Repairs.frontRightTireRepair []) True

            --
            , viewImage (Icons.Repairs.rearLeftTireRepair []) True
            , viewImage (Icons.Repairs.rearRightTireRepair []) True

            --
            , viewImage (Icons.Repairs.frontCrossAxisRepair []) True
            , viewImage (Icons.Repairs.rearCrossAxisRepair []) True
            ]
        )


viewFooter : Model -> Element Msg
viewFooter model =
    Footer.view model.currentPage
        pageToString
        [ ( Summary, "", ClickedSummaryPage )
        , ( PastRepairs, "2", ClickedPastRepairsPage )
        ]
