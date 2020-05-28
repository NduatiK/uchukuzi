module Pages.Routes.CreateRoutePage exposing (Model, Msg, init, subscriptions, tabBarItems, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Errors exposing (Errors, InputError)
import Html.Attributes exposing (id)
import Html.Events exposing (..)
import Icons
import Json.Decode as Decode exposing (Decoder, string)
import Json.Decode.Pipeline exposing (hardcoded)
import Json.Encode as Encode
import Models.Household exposing (TravelTime(..))
import Models.Location exposing (Location)
import Models.Route exposing (Route, routeDecoder)
import Navigation
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import Template.TabBar as TabBar exposing (TabBarItem(..))
import Utils.Validator exposing (..)



-- MODEL


type alias Model =
    { session : Session
    , form : Form
    , editState : Maybe EditState
    , requestState : WebData ()
    , deleteRequestState : WebData ()
    }


type alias Form =
    { name : String
    , path : List Location
    , problems : List (Errors Problem)
    }


type Problem
    = EmptyName
    | EmptyPath


type alias EditState =
    { requestState : WebData Route
    , routeID : Int
    }


type alias ValidForm =
    { name : String
    , path : List Location
    }


init : Session -> Maybe Int -> ( Model, Cmd Msg )
init session id =
    ( { session = session
      , form =
            { name = ""
            , path = []
            , problems = []
            }
      , editState =
            Maybe.andThen (EditState Loading >> Just) id
      , requestState = NotAsked
      , deleteRequestState = NotAsked
      }
    , Cmd.batch
        (case id of
            Just id_ ->
                [ Ports.cleanMap ()
                , Ports.initializeMaps
                , fetchRoute session id_
                ]

            Nothing ->
                [ Ports.initializeCustomMap { clickable = False, drawable = True } ]
        )
    )



-- UPDATE


type Msg
    = RouteNameChanged String
    | DeleteRoute Int
    | SubmitButtonMsg
    | MapPathUpdated (List Location)
    | ReceivedCreateResponse (WebData ())
    | ReceivedExistingRouteResponse (WebData Route)
    | ReceivedDeleteResponse (WebData ())
    | ReturnToRouteList


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form
    in
    case msg of
        ReturnToRouteList ->
            ( model, Navigation.rerouteTo model Navigation.Routes )

        RouteNameChanged name ->
            ( { model | form = { form | name = name } }, Cmd.none )

        SubmitButtonMsg ->
            case validateForm form of
                Ok validForm ->
                    ( { model | form = { form | problems = [] } }
                    , submit model.session validForm (Maybe.andThen (.routeID >> Just) model.editState)
                    )

                Err problems ->
                    ( { model | form = { form | problems = Errors.toClientSideErrors problems } }, Cmd.none )

        ReceivedCreateResponse response ->
            updateStatus model response

        DeleteRoute routeID ->
            ( { model | deleteRequestState = Loading }
            , deleteRoute model.session routeID
            )

        ReceivedDeleteResponse response ->
            let
                model_ =
                    { model | deleteRequestState = response }
            in
            case response of
                Success _ ->
                    ( model_
                    , Navigation.rerouteTo model Navigation.Routes
                    )

                _ ->
                    ( model_, Cmd.none )

        MapPathUpdated newPath ->
            ( { model | form = { form | path = newPath } }, Cmd.none )

        ReceivedExistingRouteResponse response ->
            let
                editState =
                    model.editState

                newModel =
                    { model | editState = Maybe.andThen (\x -> Just { x | requestState = response }) editState }
            in
            case response of
                Success route ->
                    let
                        editForm =
                            { name = route.name
                            , path = route.path
                            , problems = []
                            }
                    in
                    ( { newModel | form = editForm }, Ports.drawEditableRoute route )

                _ ->
                    ( newModel, Cmd.none )


updateStatus : Model -> WebData () -> ( Model, Cmd Msg )
updateStatus model_ response =
    let
        model =
            { model_ | requestState = response }
    in
    case response of
        Loading ->
            ( model, Cmd.none )

        Failure error ->
            let
                ( _, error_msg ) =
                    Errors.decodeErrors error

                apiFormErrors =
                    Errors.toServerSideErrors
                        error

                form =
                    model.form

                updatedForm =
                    { form | problems = form.problems ++ apiFormErrors }
            in
            ( { model | form = updatedForm }, error_msg )

        NotAsked ->
            ( model, Cmd.none )

        Success _ ->
            ( model
            , Navigation.rerouteTo model Navigation.Routes
            )



-- VIEW


view : Model -> Int -> Element Msg
view model _ =
    column
        [ width fill
        , height fill
        , spacing 24
        , padding 30
        ]
        [ viewHeading model.editState model.deleteRequestState
        , googleMap model
        , viewBody model
        ]


viewHeading : Maybe EditState -> WebData () -> Element Msg
viewHeading editState deleteRouteState =
    Element.row
        [ width fill ]
        (case editState of
            Nothing ->
                [ el Style.headerStyle (text "Create Route")
                ]

            Just editState_ ->
                [ el Style.headerStyle (text "Edit Route")
                , el [ alignRight, alignBottom ]
                    (case deleteRouteState of
                        Loading ->
                            Icons.loading [ alignRight, width (px 46), height (px 46) ]

                        Failure _ ->
                            StyledElement.failureButton [ centerX ]
                                { title = "Try Again"
                                , onPress = Just (DeleteRoute editState_.routeID)
                                }

                        _ ->
                            StyledElement.ghostButtonWithCustom
                                [ Border.color Colors.errorRed, alignBottom, alignRight ]
                                [ Colors.fillErrorRed, Font.color Colors.errorRed ]
                                { icon = Icons.trash
                                , title = "Delete Route"
                                , onPress = Just (DeleteRoute editState_.routeID)
                                }
                    )
                ]
        )


googleMap : Model -> Element Msg
googleMap model =
    let
        hasMapError =
            List.any
                (\x ->
                    case x of
                        Errors.ClientSideError y _ ->
                            y == EmptyPath

                        _ ->
                            False
                )
                model.form.problems

        mapCaptionStyle =
            if hasMapError then
                Style.errorStyle

            else
                Style.captionStyle

        mapBorderStyle =
            if hasMapError then
                [ Border.color Colors.errorRed, Border.width 2, padding 2 ]

            else
                []
    in
    column
        [ width fill
        , spacing 8
        ]
        [ el
            [ width fill
            , height (px 400)
            ]
            (StyledElement.googleMap
                ([ width fill
                 , height fill
                 , Border.width 1
                 ]
                    ++ mapBorderStyle
                )
            )
        , el mapCaptionStyle (text "Click on the map to start drawing the route")
        ]


viewBody : Model -> Element Msg
viewBody model =
    Element.column
        [ width fill, spacing 40, alignTop ]
        [ viewForm model
        ]


viewForm : Model -> Element Msg
viewForm model =
    Element.column
        [ width (fillPortion 1), spacing 26 ]
        [ viewRouteNameInput model.form.problems model.form.name
        , row []
            [ viewButton model.requestState
            ]
        ]


viewRouteNameInput : List (Errors Problem) -> String -> Element Msg
viewRouteNameInput problems name =
    StyledElement.emailInput
        [ width
            (fill
                |> maximum 300
            )
        ]
        { ariaLabel = "Route Name"
        , caption = Nothing
        , errorCaption = Errors.inputErrorsFor problems "name" [ EmptyName ]
        , icon = Nothing
        , onChange = RouteNameChanged
        , placeholder = Just (Input.placeholder [] (text "eg Riruta Route"))
        , title = "Name"
        , value = name
        }


viewButton : WebData a -> Element Msg
viewButton requestState =
    el (Style.labelStyle ++ [ width fill, paddingEach { edges | right = 24 } ])
        none


submit : Session -> ValidForm -> Maybe Int -> Cmd Msg
submit session form editingID =
    let
        params =
            Encode.object
                [ ( "name", Encode.string form.name )
                , ( "path", Encode.list encodeLocation form.path )
                ]
    in
    case editingID of
        Just id ->
            Api.patch session (Endpoint.route id) params aDecoder
                |> Cmd.map ReceivedCreateResponse

        Nothing ->
            Api.post session Endpoint.routes params aDecoder
                |> Cmd.map ReceivedCreateResponse


aDecoder : Decoder ()
aDecoder =
    Decode.succeed ()


encodeLocation : Location -> Encode.Value
encodeLocation location =
    Encode.object
        [ ( "lat", Encode.float location.lat )
        , ( "lng", Encode.float location.lng )
        ]


validateForm : Form -> Result (List ( Problem, String )) ValidForm
validateForm form =
    let
        problems =
            List.concat
                [ if List.isEmpty form.path then
                    [ ( EmptyPath, "Required" ) ]

                  else
                    []
                , if String.isEmpty (String.trim form.name) then
                    [ ( EmptyName, "Please provide a route name" ) ]

                  else
                    []
                ]
    in
    case problems of
        [] ->
            Ok
                { path = form.path
                , name = form.name
                }

        _ ->
            Err problems


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Ports.updatedPath MapPathUpdated
        ]


fetchRoute : Session -> Int -> Cmd Msg
fetchRoute session id =
    Api.get session (Endpoint.route id) routeDecoder
        |> Cmd.map ReceivedExistingRouteResponse


deleteRoute : Session -> Int -> Cmd Msg
deleteRoute session id =
    Api.delete session (Endpoint.route id) (Decode.succeed ())
        |> Cmd.map ReceivedDeleteResponse


tabBarItems { requestState } =
    case requestState of
        Failure _ ->
            [ TabBar.Button
                { title = "Cancel"
                , icon = Icons.close
                , onPress = ReturnToRouteList
                }
            , TabBar.ErrorButton
                { title = "Try Again"
                , icon = Icons.save
                , onPress = SubmitButtonMsg
                }
            ]

        Loading ->
            [ TabBar.LoadingButton
                { title = ""
                }
            ]

        _ ->
            [ TabBar.Button
                { title = "Cancel"
                , icon = Icons.close
                , onPress = ReturnToRouteList
                }
            , TabBar.Button
                { title = "Save"
                , icon = Icons.save
                , onPress = SubmitButtonMsg
                }
            ]
