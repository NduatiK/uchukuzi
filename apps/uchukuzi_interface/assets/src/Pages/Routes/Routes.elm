module Pages.Routes.Routes exposing (Model, Msg, init, update, view, tabItems)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Errors
import Html.Events
import Icons
import Json.Decode exposing (list, succeed)
import Models.Route exposing (Route, routeDecoder)
import Navigation
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import Template.TabBar as TabBar exposing (TabBarItem(..))


type alias Model =
    { session : Session
    , routes : WebData (List Route)
    , filterText : String
    }


type Msg
    = CreateRoute
    | EditRoute Route
    | UpdatedSearchText String
    | ServerResponse (WebData (List Route))
    | HoverOver Route
    | HoverLeft Route


init : Session -> ( Model, Cmd Msg )
init session =
    ( Model session NotAsked ""
    , Cmd.batch
        [ Ports.initializeMaps
        , fetchRoutes session
        ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdatedSearchText string ->
            ( { model | filterText = string }, Cmd.none )

        CreateRoute ->
            ( model, Navigation.rerouteTo model Navigation.CreateRoute )

        EditRoute route ->
            ( model, Navigation.rerouteTo model (Navigation.EditRoute route.id) )

        HoverOver route ->
            ( model, Ports.highlightPath { routeID = route.id, highlighted = True } )

        HoverLeft route ->
            ( model, Ports.highlightPath { routeID = route.id, highlighted = False } )

        ServerResponse response ->
            let
                newModel =
                    { model | routes = response }
            in
            case response of
                Success routes ->
                    ( newModel
                    , Ports.bulkDrawPath (List.map (\route -> { routeID = route.id, path = route.path, highlighted = False }) routes)
                    )

                Failure error ->
                    let
                        ( _, error_msg ) =
                            Errors.decodeErrors error
                    in
                    ( newModel, error_msg )

                _ ->
                    ( newModel, Cmd.none )



-- ( newModel, Ports.bulkUpdateBusMap (locationUpdatesFrom newModel) )


view : Model -> Int -> Element Msg
view model viewHeight =
    row [ paddingXY 30 30, width fill, spacing 32, height (fill |> maximum viewHeight) ]
        [ viewBody model (viewHeight - 60)
        , googleMap
        ]


viewBody model viewHeight =
    column [ width fill, height (px viewHeight), spacing 20 ]
        [ viewHeading model
        , viewRoutes model
        ]


viewHeading : Model -> Element Msg
viewHeading model =
    Style.iconHeader Icons.pin "Routes"


viewRoutes model =
    case model.routes of
        Failure error ->
            let
                ( apiError, _ ) =
                    Errors.decodeErrors error
            in
            text (Errors.errorToString apiError)

        Success [] ->
            column (centerX :: spacing 8 :: centerY :: Style.labelStyle)
                [ el [ centerX ] (text "You have no routes set up.")
                , el [ centerX ] (text "Click the + button above to create one.")
                ]

        Success routes ->
            el
                [ scrollbarY
                , height fill
                , width fill
                ]
                (wrappedRow
                    [ spacing 10
                    , paddingEach { edges | right = 10, bottom = 10 }
                    ]
                    (List.map viewRoute routes)
                 -- (List.map viewRoute (routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes ++ routes))
                )

        _ ->
            el [ width fill, height fill ] (Icons.loading [ centerX, centerY ])


viewRoute : Route -> Element Msg
viewRoute route =
    -- el [] none
    -- viewTrip : Maybe Trip -> Time.Zone -> Trip -> Element Msg
    -- viewTrip selectedTrip timezone trip =
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

                   --    , Font.bold
                   ]

        selectionStyles =
            []

        --     if Just trip == selectedTrip then
        --         [ Border.color (rgb255 97 165 145)
        --         , moveUp 2
        --         , Border.shadow { offset = ( 0, 12 ), blur = 20, size = 0, color = rgba255 97 165 145 0.3 }
        --         ]
        --     else
        --         [ Border.color (rgba255 197 197 197 0.5)
        --         -- , Border.shadow { offset = ( 0, 2 ), size = 0, blur = 12, color = rgba 0 0 0 0.14 }
        --         ]
    in
    row
        ([ height (px 64)
         , width (fillPortion 1 |> minimum 200)
         , spacing 8
         , paddingXY 12 11
         , Border.solid
         , Border.width 1
         , Border.color Colors.sassyGrey
         , alignTop
         , htmlAttribute (Html.Events.onMouseOver (HoverOver route))
         , htmlAttribute (Html.Events.onMouseLeave (HoverLeft route))
         , Style.animatesShadow
         , inFront
            (Icons.edit [ alpha 0.3, alignRight, padding 12, centerY ])
         , inFront
            (StyledElement.plainButton [ alignRight, padding 12, centerY, alpha 0.01, mouseOver [ alpha 1 ] ]
                { label = Icons.edit [ Colors.fillPurple ]
                , onPress = Just (EditRoute route)
                }
            )
         ]
            ++ selectionStyles
        )
        [ column [ spacing 8 ]
            [ el routeStyle (text route.name)
            , el timeStyle
                (text
                    (Maybe.withDefault "No bus assigned" (Maybe.andThen (.numberPlate >> Just) route.bus))
                )

            --  el (alignRight :: timeStyle) (text (Utils.DateFormatter.timeFormatter timezone trip.startTime))
            -- , el (alignRight :: timeStyle) (text (Utils.DateFormatter.timeFormatter timezone trip.endTime))
            -- , el routeStyle (text trip.route)
            ]
        ]


tabItems =
    [ TabBar.Button
        { title = "Add Route"
        , icon = Icons.add
        , onPress = CreateRoute
        }
    ]


googleMap : Element Msg
googleMap =
    StyledElement.googleMap
        [ width fill

        -- , height (fill |> minimum 500)
        , height fill
        ]


fetchRoutes : Session -> Cmd Msg
fetchRoutes session =
    Api.get session Endpoint.routes (list routeDecoder)
        |> Cmd.map ServerResponse
