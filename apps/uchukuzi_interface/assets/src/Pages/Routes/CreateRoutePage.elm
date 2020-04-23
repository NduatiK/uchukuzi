module Pages.Routes.CreateRoutePage exposing (Model, Msg, init, subscriptions, update, view)

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
import Http
import Icons
import Json.Decode as Decode exposing (Decoder, string)
import Json.Decode.Pipeline exposing (hardcoded)
import Json.Encode as Encode
import Models.Household exposing (TravelTime(..))
import Models.Location exposing (Location)
import Navigation exposing (..)
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement exposing (toDropDownView)
import StyledElement.DropDown as Dropdown
import Utils.Validator exposing (..)
import Views.Heading exposing (viewHeading)



-- MODEL


type alias Model =
    { session : Session
    , form : Form
    }


type alias Form =
    { name : String
    , path : List Location
    , problems : List (Errors Problem)
    }


type Problem
    = EmptyName
    | EmptyPath


type alias ValidForm =
    { name : String
    , path : List Location
    }


type alias Student =
    { name : String
    , time : TravelTime
    }


type alias Guardian =
    { name : String
    , phoneNumber : String
    , email : String
    }


type Msg
    = RouteNameChanged String
    | DeleteRoute
    | SubmitButtonMsg
    | MapPathUpdated (List Location)
    | ServerResponse (WebData ())


emptyForm : Session -> Model
emptyForm session =
    { session = session
    , form =
        { name = ""
        , path = []
        , problems = []
        }
    }


init : Session -> ( Model, Cmd msg )
init session =
    ( emptyForm session
    , Cmd.batch
        [ Ports.initializeCustomMap { clickable = False, drawable = True }
        ]
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form
    in
    case msg of
        RouteNameChanged name ->
            ( { model | form = { form | name = name } }, Cmd.none )

        SubmitButtonMsg ->
            case validateForm form of
                Ok validForm ->
                    ( { model | form = { form | problems = [] } }, submit model.session validForm )

                Err problems ->
                    ( { model | form = { form | problems = Errors.toClientSideErrors problems } }, Cmd.none )

        ServerResponse response ->
            updateStatus model response

        DeleteRoute ->
            ( { model | form = { form | path = [] } }, Cmd.none )

        MapPathUpdated newPath ->
            ( { model | form = { form | path = newPath } }, Cmd.none )


updateStatus : Model -> WebData () -> ( Model, Cmd Msg )
updateStatus model webData =
    case webData of
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

        Success creds ->
            ( model
            , Navigation.rerouteTo model Navigation.Routes
            )



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    column
        [ width fill
        , height fill
        , spacing 24
        , padding 24
        ]
        [ viewHeading "Create Route" Nothing
        , googleMap model
        , viewBody model
        ]


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

                 --  , Background.color Colors.darkGreen
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

        -- -- , viewDivider
        -- , el Style.header2Style (text "Students")
        -- -- , viewLocationInput household.home_location
        -- , viewStudentsInput model.form
        -- , viewDivider
        -- , el Style.header2Style
        --     (text "Guardian's contacts")
        -- , viewGuardianNameInput model.form.problems household.guardian.name
        -- , wrappedRow [ spacing 24 ]
        --     [ viewEmailInput model.form.problems household.guardian.email
        --     , viewPhoneInput model.form.problems household.guardian.phoneNumber
        --     ]
        -- , viewShareLocationInput model.form.canTrack
        , viewButton
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


viewDivider : Element Msg
viewDivider =
    el
        [ width (fill |> maximum 480)
        , padding 10
        , spacing 7
        , Border.widthEach
            { bottom = 2
            , left = 0
            , right = 0
            , top = 0
            }
        , Border.color (rgb255 243 243 243)
        ]
        Element.none


viewButton : Element Msg
viewButton =
    el (Style.labelStyle ++ [ width fill, paddingEach { edges | right = 24 } ])
        (StyledElement.button [ alignRight ]
            { onPress = Just SubmitButtonMsg
            , label = text "Save"
            }
        )


submit : Session -> ValidForm -> Cmd Msg
submit session form =
    let
        params =
            Encode.object
                [ ( "name", Encode.string form.name )
                , ( "path", Encode.list encodeLocation form.path )
                ]
                |> Http.jsonBody
    in
    Api.post session Endpoint.routes params aDecoder
        |> Cmd.map ServerResponse


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
subscriptions model =
    Sub.batch
        [ --     Ports.autocompleteError (always AutocompleteError)
          Ports.updatedPath MapPathUpdated
        ]
