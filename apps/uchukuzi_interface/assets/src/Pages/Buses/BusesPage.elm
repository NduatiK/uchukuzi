module Pages.Buses.BusesPage exposing (Model, Msg, init, locationUpdateMsg, subscriptions, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Font as Font
import Errors
import Icons
import Json.Decode exposing (list)
import Models.Bus exposing (Bus, LocationUpdate, busDecoder, vehicleTypeToString)
import Models.Location exposing (Location)
import Navigation
import Pages.Buses.Bus.Navigation exposing (BusPage(..))
import Ports
import RemoteData exposing (RemoteData(..), WebData)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement



-- MODEL


type alias Model =
    { session : Session
    , buses : WebData (List Bus)
    , locationUpdates : Dict Int LocationUpdate
    , filterText : String
    , selectedBus : Maybe Bus
    }


type Msg
    = SelectedBus Bus
    | CreateBus
    | ChangedFilterText String
    | ServerResponse (WebData (List Bus))
    | LocationUpdate (Dict Int LocationUpdate)
    | MapReady Bool
    | PreviewBus (Maybe Bus)


locationUpdateMsg : Dict Int LocationUpdate -> Msg
locationUpdateMsg data =
    LocationUpdate data


init : Session -> Dict Int LocationUpdate -> ( Model, Cmd Msg )
init session locationUpdates =
    ( { session = session
      , buses = Loading
      , locationUpdates = locationUpdates
      , filterText = ""
      , selectedBus = Nothing
      }
    , Cmd.batch
        [ fetchBuses session
        , Ports.initializeMaps
        , Ports.initializeLiveView ()
        ]
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ServerResponse response ->
            let
                newModel =
                    { model | buses = response }
            in
            case response of
                Failure error ->
                    let
                        ( _, error_msg ) =
                            Errors.decodeErrors error
                    in
                    ( newModel, error_msg )

                _ ->
                    ( newModel, Ports.bulkUpdateBusMap (locationUpdatesFrom newModel) )

        ChangedFilterText filterText ->
            ( { model | filterText = filterText }
            , Cmd.none
            )

        SelectedBus bus ->
            ( model, Navigation.rerouteTo model (Navigation.Bus bus.id About) )

        CreateBus ->
            ( model, Navigation.rerouteTo model Navigation.BusRegistration )

        LocationUpdate locationUpdates ->
            ( { model | locationUpdates = locationUpdates }, Ports.bulkUpdateBusMap (locationUpdatesFrom model) )

        MapReady _ ->
            ( model, Ports.bulkUpdateBusMap (locationUpdatesFrom model) )

        PreviewBus bus ->
            if bus == model.selectedBus then
                ( { model | selectedBus = Nothing }, Cmd.none )

            else
                ( { model | selectedBus = bus }, Cmd.none )


locationUpdatesFrom : Model -> List LocationUpdate
locationUpdatesFrom model =
    let
        locationUpdates =
            case model.buses of
                Success buses ->
                    List.concat
                        (List.map
                            (\bus ->
                                case Dict.get bus.id model.locationUpdates of
                                    Just locationUpdate ->
                                        [ locationUpdate ]

                                    Nothing ->
                                        case bus.last_seen of
                                            Just locationUpdate_ ->
                                                [ locationUpdate_ ]

                                            _ ->
                                                []
                            )
                            buses
                        )

                _ ->
                    Dict.values model.locationUpdates
    in
    locationUpdates



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    column
        [ width fill
        , height (px viewHeight)
        , spacing 40
        , paddingXY 90 70
        ]
        [ googleMap (busesFromModel model.buses) model.selectedBus
        , viewBody model
        ]


viewBody : Model -> Element Msg
viewBody model =
    let
        body =
            case model.buses of
                NotAsked ->
                    text "Initialising."

                Loading ->
                    el [ width fill, height fill ] (Icons.loading [ centerX, centerY ])

                Failure error ->
                    let
                        ( apiError, _ ) =
                            Errors.decodeErrors error
                    in
                    text (Errors.errorToString apiError)

                Success buses ->
                    column [ width fill ]
                        [ viewBuses buses model.filterText
                        ]
    in
    Element.column
        [ spacing 40
        , width fill
        , paddingEach { edges | bottom = 44 }
        ]
        [ -- , viewHeading "All Buses" model.filterText
          body
        , el [] none
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
                            String.toLower (vehicleTypeToString x.vehicleType)
                    in
                    List.any (String.contains lowerFilterText) [ numberPlate, vehicleType ]
                )
                buses
    in
    el
        [ width fill
        ]
        (column [ width fill ]
            [ row [ width fill, spacing 10 ]
                [ el Style.headerStyle (text "Vehicles")

                -- , StyledElement.textInput
                --     [ centerX, width (fill |> maximum 300), centerY ]
                --     { title = ""
                --     , caption = Nothing
                --     , errorCaption = Nothing
                --     , value = filterText
                --     , onChange = String.toUpper >> ChangedFilterText
                --     , placeholder = Just (Input.placeholder [] (text "Search"))
                --     , ariaLabel = "Filter buses"
                --     , icon = Just Icons.search
                --     }
                , StyledElement.button
                    [ alignRight ]
                    { label =
                        row [ spacing 8 ]
                            [ Icons.add [ alpha 1, Colors.fillWhite ]
                            , el [ centerY ] (text "Add Bus")
                            ]
                    , onPress = Just CreateBus
                    }
                ]
            , el []
                (case ( filteredBuses, filterText ) of
                    ( [], "" ) ->
                        el (centerX :: centerY :: paddingXY 0 30 :: Style.labelStyle) (text "No buses created yet")

                    ( [], _ ) ->
                        el (centerX :: centerY :: paddingXY 0 30 :: Style.labelStyle) (text ("No matches for " ++ filterText))

                    ( someBuses, _ ) ->
                        viewTable someBuses
                )
            ]
        )


viewTable buses =
    let
        tableHeader text =
            el Style.tableHeaderStyle (Element.text (String.toUpper text))
    in
    Element.table
        [ spacing 20, paddingEach { edges | top = 16, left = 16, right = 16, bottom = 24 } ]
        { data = buses
        , columns =
            [ { header = tableHeader "NUMBER PLATE"
              , width = shrink
              , view =
                    \bus ->
                        StyledElement.textLink [ width (fill |> minimum 220), centerY ]
                            { label = text bus.numberPlate
                            , route = Navigation.Bus bus.id About
                            }
              }
            , { header = tableHeader ""
              , width = shrink
              , view =
                    \bus ->
                        StyledElement.iconButton [ padding 0, Background.color Colors.transparent ]
                            { icon = Icons.pin
                            , iconAttrs = []
                            , onPress = Just (PreviewBus (Just bus))
                            }
              }
            , { header = tableHeader "ROUTE"
              , width = shrink
              , view =
                    \bus ->
                        case bus.route of
                            Just route ->
                                StyledElement.textLink [ centerY ]
                                    { label = text route.name
                                    , route = Navigation.Routes

                                    -- , route = Navigation.Routes bus.id Nothing
                                    }

                            Nothing ->
                                none
              }
            ]
        }


googleMap : Maybe (List Bus) -> Maybe Bus -> Element Msg
googleMap buses bus =
    column
        [ width fill
        , height fill
        , clip
        , inFront
            (column
                [ width (px 300)
                , alignRight
                , height fill
                , Style.animatesAll
                , if bus == Nothing then
                    moveRight 300

                  else
                    moveRight 0
                ]
                [ el
                    [ width fill
                    , height fill
                    , Background.color (Colors.withAlpha Colors.darkness 0.9)
                    , Style.blurredStyle
                    , Style.animatesAll
                    ]
                    (viewMapDetails bus)
                , el [ height (px 2), width fill ] none
                ]
            )
        ]
        [ StyledElement.googleMap
            [ width fill
            , height (fill |> minimum 500)
            ]
        , el [ height (px 2), width fill, Background.color Colors.darkness ] none
        ]


viewMapDetails : Maybe Bus -> Element Msg
viewMapDetails maybeBus =
    case maybeBus of
        Just bus ->
            let
                viewStudents =
                    row []
                        [ column [ spacing 8 ]
                            [ el (Style.header2Style ++ [ Font.color Colors.white ]) (text "Students")
                            , el (Style.labelStyle ++ [ Font.color Colors.white ]) (text "3 Onboard")
                            , el (Style.labelStyle ++ [ Font.color Colors.white ]) (text "4 Registered")
                            ]
                        ]

                viewCrew =
                    row []
                        [ column [ spacing 12 ]
                            [ el (Style.header2Style ++ [ Font.color Colors.white ]) (text "Crew")
                            , wrappedRow (Style.labelStyle ++ [ Font.color Colors.white, spacing 4 ]) [ text "Driver", el [ Font.semiBold ] (text "Carlos Montaigne") ]
                            , wrappedRow (Style.labelStyle ++ [ Font.color Colors.white, spacing 4 ]) [ text "Assistant", el [ Font.semiBold ] (text "Harvey Mudd") ]
                            ]
                        ]
            in
            column [ paddingXY 20 20, spacing 16, width fill ]
                [ el (Style.headerStyle ++ [ Font.color Colors.white, Font.letterSpacing 1, padding 0 ]) (text bus.numberPlate)
                , el (Style.labelStyle ++ [ Font.color Colors.white ])
                    (case bus.route of
                        Just route ->
                            text route.name

                        Nothing ->
                            text "Route not set"
                    )
                , el [ height (px 2), width fill, Background.color Colors.darkness ] none
                , viewStudents
                , el [ height (px 2), width fill, Background.color Colors.darkness ] none
                , viewCrew
                ]

        Nothing ->
            none



-- HTTP


fetchBuses : Session -> Cmd Msg
fetchBuses session =
    Api.get session Endpoint.buses (list busDecoder)
        |> Cmd.map ServerResponse


busesFromModel : WebData (List Bus) -> Maybe (List Bus)
busesFromModel model =
    case model of
        Success buses ->
            Just buses

        _ ->
            Nothing


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.mapReady MapReady
        ]
