module Pages.Login exposing (Model, Msg, init, update, view)

import Api exposing (SuccessfulLogin)
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Errors
import Icons
import Json.Decode as Decode exposing (Decoder, string)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode
import Models.Location exposing (Location, locationDecoder)
import Navigation exposing (LoginRedirect, Route)
import RemoteData exposing (..)
import Session exposing (Session)
import Style
import StyledElement



-- MODEL


type alias Model =
    { session : Session
    , form : Form
    , error : Maybe String
    , message : Maybe String
    , status : WebData SuccessfulLogin
    }


type alias Form =
    { email : String
    , password : String
    }


init : Session -> Maybe LoginRedirect -> ( Model, Cmd Msg )
init session redirect =
    let
        message =
            case redirect of
                Nothing ->
                    Nothing

                Just Navigation.ConfirmEmail ->
                    Just "We have sent you an email, please verify your account before logging in"
    in
    ( { session = session
      , form = { email = "", password = "" }
      , error = Nothing
      , message = message
      , status = NotAsked
      }
    , Cmd.none
      -- , Api.logout
    )



-- UPDATE


type Msg
    = UpdatedEmail String
    | UpdatedPassword String
    | SubmitForm
    | ReceivedLoginResponse (WebData SuccessfulLogin)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form
    in
    case msg of
        UpdatedPassword password ->
            ( { model | form = { form | password = password } }, Cmd.none )

        UpdatedEmail email ->
            ( { model | form = { form | email = email } }, Cmd.none )

        SubmitForm ->
            ( { model | error = Nothing, status = Loading }, login model.session form )

        ReceivedLoginResponse requestStatus ->
            let
                updatedModel =
                    { model | status = requestStatus }
            in
            updateStatus updatedModel requestStatus


updateStatus : Model -> WebData SuccessfulLogin -> ( Model, Cmd Msg )
updateStatus model msg =
    case msg of
        Loading ->
            ( model, Cmd.none )

        Failure error ->
            let
                ( apiError, _ ) =
                    Errors.decodeErrors error
            in
            ( { model | error = Just (Errors.errorToString apiError) }, Cmd.none )

        NotAsked ->
            ( model, Cmd.none )

        Success data ->
            ( { model | session = Session.withCredentials model.session (Just data.creds) }
            , Cmd.batch
                [ Api.storeCredentials data.creds
                , Models.Location.storeSchoolLocation data.location
                , Navigation.rerouteTo model Navigation.Buses
                ]
            )


view : Model -> Element Msg
view model =
    let
        spacer =
            el [] none
    in
    column [ centerX, centerY, width (fill |> maximum 500), spacing 10, paddingXY 30 0 ]
        [ el (alignLeft :: Style.headerStyle)
            (text
                (if model.message == Nothing then
                    "Welcome back!"

                 else
                    "Welcome!"
                )
            )
        , viewMessage model.message
        , StyledElement.textInput [ centerX ]
            { title = "Email"
            , caption = Nothing
            , errorCaption = Nothing
            , value = model.form.email
            , onChange = UpdatedEmail
            , placeholder = Nothing
            , ariaLabel = "Email input"
            , icon = Nothing
            }
        , spacer
        , StyledElement.passwordInput [ centerX ]
            { title = "Password"
            , caption = Nothing
            , errorCaption = Nothing
            , value = model.form.password
            , onChange = UpdatedPassword
            , placeholder = Nothing
            , ariaLabel = "Password input"
            , icon = Nothing
            , newPassword = False
            }
        , viewError model.error
        , spacer
        , viewButton model
        , viewDivider
        , viewFooter
        , el [ height (fill |> minimum 100) ] none
        ]


viewError : Maybe String -> Element Msg
viewError error =
    case error of
        Nothing ->
            none

        Just errorStr ->
            row
                ([ width fill, padding 10, Background.color (Colors.withAlpha Colors.errorRed 0.5) ] ++ Style.labelStyle)
                [ Element.paragraph [] [ text errorStr ] ]


viewMessage : Maybe String -> Element Msg
viewMessage message =
    case message of
        Nothing ->
            none

        Just messageStr ->
            row
                ([ width fill, padding 10, Background.color (Colors.withAlpha Colors.teal 0.5) ] ++ Style.labelStyle)
                [ Element.paragraph [] [ text messageStr ] ]


viewFooter : Element msg
viewFooter =
    column []
        [ wrappedRow [ spacing 8 ]
            [ el (Font.size 15 :: Style.labelStyle)
                (text "Don’t have an account?")
            , row [ spacing 8 ]
                [ StyledElement.textLink [ Font.color Colors.darkGreen, Font.size 15 ] { label = text "Sign up with Flotilla", route = Navigation.Signup }
                , Icons.chevronDown [ rotate (-pi / 2) ]
                ]
            ]

        -- , row [ spacing 8 ]
        --     [ StyledElement.textLink [ Font.color Colors.darkGreen, Font.size 15 ] { label = text "Forgot your password?", route = Navigation.Home }
        --     , Icons.chevronDown [ rotate (-pi / 2) ]
        --     ]
        ]


viewDivider : Element msg
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


login : Session -> Form -> Cmd Msg
login session form =
    let
        params =
            Encode.object
                [ ( "email", Encode.string form.email )
                , ( "password", Encode.string form.password )
                ]
    in
    Api.post session Endpoint.login params Api.loginDecoder
        |> Cmd.map ReceivedLoginResponse


viewButton : Model -> Element Msg
viewButton { status } =
    case status of
        Loading ->
            Icons.loading [ alignRight, width (px 46), height (px 46) ]

        _ ->
            StyledElement.button [ alignRight ] { label = text "Done", onPress = Just SubmitForm }
