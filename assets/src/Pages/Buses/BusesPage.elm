module Pages.Buses.BusesPage exposing (Model, Msg, init, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Errors
import Html exposing (Html)
import Html.Attributes exposing (id)
import Icons
import Json.Decode as Decode exposing (Decoder, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)
import Ports
import RemoteData exposing (RemoteData(..), WebData)
import Route
import Session exposing (Session)
import Style exposing (edges)
import StyledElement



-- MODEL


type alias Model =
    { session : Session
    , buses : WebData (List Bus)
    , filterText : String
    , height : Int
    }


type alias Bus =
    { id : Int
    , numberPlate : String
    , seats_available : Int
    , vehicleType : String
    , stated_milage : Float

    -- , current_location : Maybe Location
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


init : Session -> Int -> ( Model, Cmd Msg )
init session height =
    ( Model session Loading "" height
    , Cmd.batch [ fetchBuses session, Ports.initializeMaps False ]
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ServerResponse response ->
            case response of
                Failure error ->
                    let
                        ( _, error_msg ) =
                            Errors.decodeErrors error
                    in
                    ( { model | buses = response }, error_msg )

                _ ->
                    ( { model | buses = response }, Cmd.none )

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
    wrappedRow
        [ width fill
        , height (px model.height)
        ]
        [ el
            [ paddingEach { edges | right = 10 }
            , width fill
            , height fill
            ]
            (viewBody model)
        , google_map (busesFromModel model.buses)
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
                        ( apiError, _ ) =
                            Errors.decodeErrors error
                    in
                    text (Errors.errorToString apiError)

                Success buses ->
                    viewBuses buses model.filterText
    in
    el [ width fill, height fill, alignTop ]
        (Element.column
            [ paddingXY 10 0
            , spacing 40
            , width (fillPortion 2 |> minimum 400)
            ]
            [ el [] none
            , viewHeading "All Buses" model.filterText
            , body
            ]
        )


viewHeading : String -> String -> Element Msg
viewHeading title filterText =
    Element.row
        [ width fill, spacing 52, paddingXY 30 0 ]
        [ el
            Style.headerStyle
            (text title)
        , StyledElement.textInput [ alignRight, width (fill |> maximum 300), centerY ]
            { title = ""
            , caption = Nothing
            , errorCaption = Nothing
            , value = filterText
            , onChange = String.toUpper >> ChangedFilterText
            , placeholder = Just (Input.placeholder [] (text "Search"))
            , ariaLabel = "Filter buses"
            , icon = Just Icons.search
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
                                [ Icons.timeline [ Colors.fillDarkGreen, alpha 1, width <| px 18, height <| px 18 ]
                                , el Style.captionLabelStyle (text bus.numberPlate)
                                ]
                            ]
                        , el [ alignRight, centerY, Background.color (rgb255 238 238 238), width <| px 40, height <| px 40, Border.rounded 20 ] (Icons.pin [ centerX, centerY ])
                        ]
                }
    in
    case ( filteredBuses, filterText ) of
        ( [], "" ) ->
            el [ padding 30 ] (text "No buses created yet")

        ( [], _ ) ->
            el [ padding 30 ] (text ("No matches for " ++ filterText))

        ( someBuses, _ ) ->
            wrappedRow
                [ padding 30
                , width fill
                , alignTop
                , height fill
                , spacing 20
                , scrollbarY
                ]
                (List.map busView someBuses)


google_map : Maybe (List Bus) -> Element Msg
google_map buses =
    StyledElement.googleMap
        [ width (fillPortion 1 |> minimum 400)
        , height (fill |> minimum 400)
        ]



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



-- |> required "location" (nullable locationDecoder)


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
