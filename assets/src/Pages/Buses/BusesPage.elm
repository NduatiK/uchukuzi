module Pages.Buses.BusesPage exposing (Model, Msg, init, update, view)

import Api
import Api.Endpoint as Endpoint
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes exposing (id)
import Http
import Icons
import Json.Decode as Decode exposing (Decoder, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)
import RemoteData exposing (RemoteData(..), WebData)
import Route
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import Views.Heading



-- MODEL


type alias Model =
    { session : Session
    , buses : WebData (List Bus)
    , filterText : String
    }


type alias Bus =
    { id : Int
    , numberPlate : String
    , seats_available : Int
    , vehicleType : String
    , stated_milage : Float
    , current_location : Maybe Location
    }


type alias Location =
    { longitude : Float
    , latitude : Float
    }


type Msg
    = SelectedBus Bus
    | CreateBus
    | ChangedFilterText String
    | ServerResponse (WebData (List Bus))


init : Session -> ( Model, Cmd Msg )
init session =
    ( Model session Loading ""
    , fetchBuses session
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ServerResponse buses ->
            ( { model | buses = buses }
            , Cmd.none
            )

        ChangedFilterText filterText ->
            ( { model | filterText = filterText }
            , Cmd.none
            )

        SelectedBus bus ->
            ( model, Route.rerouteTo model (Route.Bus bus.id) )

        CreateBus ->
            ( model, Route.rerouteTo model Route.BusRegistration )



-- VIEW


view : Model -> Element Msg
view model =
    column
        [ width fill
        , height fill
        ]
        [ google_map (busesFromModel model.buses)
        , el
            [ paddingEach { edges | right = 10 }
            , width fill
            , height (fillPortion 1)
            ]
            (viewBody model)
        ]


viewBody : Model -> Element Msg
viewBody model =
    let
        body =
            case model.buses of
                NotAsked ->
                    text "Initialising."

                Loading ->
                    Element.column [ spacing 40 ]
                        [ el
                            [ padding 10
                            , width fill
                            , alignTop
                            , height fill
                            ]
                            none
                        ]

                Failure error ->
                    let
                        apiError =
                            Api.decodeErrors error
                    in
                    text (Api.errorToString apiError)

                Success buses ->
                    Element.column
                        [ padding 30
                        , spacing 40
                        , width fill
                        ]
                        [ viewHeading "All Buses" model.filterText
                        , viewBuses buses model.filterText
                        ]
    in
    el [ width fill, height fill, alignTop ] body


viewHeading : String -> String -> Element Msg
viewHeading title filterText =
    Element.row
        [ width fill, spacing 52 ]
        [ el
            Style.headerStyle
            (text title)
        , StyledElement.textInput [ alignRight, width (fill |> maximum 300), centerY ]
            { title = ""
            , caption = Nothing
            , errorCaption = Nothing
            , value = filterText
            , onChange = ChangedFilterText
            , placeholder = Just (Input.placeholder [] (text "Search"))
            , ariaLabel = "Filter buses"
            , icon = Just Icons.filter
            }
        , StyledElement.iconButton [ centerY ]
            { onPress = Just CreateBus
            , icon = Icons.addWhite
            , iconAttrs = []
            }
        ]


viewBuses : List Bus -> String -> Element Msg
viewBuses buses filterText =
    let
        lowerFilterText =
            String.toLower filterText

        filteredBuses =
            List.filter
                (\x ->
                    let
                        numberPlate =
                            String.toLower x.numberPlate

                        vehicleType =
                            String.toLower x.vehicleType
                    in
                    List.any (String.contains lowerFilterText) [ numberPlate, vehicleType ]
                )
                buses

        busView : Bus -> Element Msg
        busView bus =
            Input.button [ width (fill |> maximum 325 |> minimum 250) ]
                { onPress = Just (SelectedBus bus)
                , label =
                    row
                        ([ paddingEach { edges | left = 20, right = 14, top = 24, bottom = 24 }
                         , width fill
                         ]
                            ++ Style.borderedContainer
                        )
                        [ column [ alignLeft, centerY, spacing 12 ]
                            [ el Style.labelStyle (text bus.numberPlate)
                            , row [ spacing 7 ]
                                [ Icons.timeline [ Style.fillColorDarkGreen, alpha 1, width <| px 18, height <| px 18 ]
                                , el Style.captionLabelStyle (text bus.numberPlate)
                                ]
                            ]
                        , el [ alignRight, centerY, Background.color (rgb255 238 238 238), width <| px 40, height <| px 40, Border.rounded 20 ] (Icons.pin [ centerX, centerY ])
                        ]
                }
    in
    case filteredBuses of
        [] ->
            text "No buses created yet"

        someBuses ->
            wrappedRow
                [ padding 10
                , width fill
                , alignTop
                , height fill
                , spacing 20
                ]
                (List.map busView someBuses)


google_map : Maybe (List Bus) -> Element Msg
google_map buses =
    el
        [ width fill
        , height (fill |> minimum 400)
        , Background.color Style.darkGreenColor
        , htmlAttribute (id "google-map")
        , Border.width 1
        ]
        none



-- HTTP


fetchBuses : Session -> Cmd Msg
fetchBuses session =
    Api.get session Endpoint.buses (list busDecoder)
        |> Cmd.map ServerResponse


busDecoder : Decoder Bus
busDecoder =
    Decode.succeed Bus
        |> required "id" int
        |> required "number_plate" string
        |> required "seats_available" int
        |> required "vehicle_type" string
        |> required "stated_milage" float
        |> required "location" (nullable locationDecoder)


locationDecoder : Decoder Location
locationDecoder =
    Decode.succeed Location
        |> required "longitude" float
        |> required "latitude" float


busesFromModel model =
    case model of
        Success buses ->
            Just buses

        _ ->
            Nothing
