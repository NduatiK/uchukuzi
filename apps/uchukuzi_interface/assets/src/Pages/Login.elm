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
import StyledElement.WebDataView as WebDataView



-- MODEL


type alias Model =
    { session : Session
    , form : Form
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
            ( { model | status = Loading }, login model.session form )

        ReceivedLoginResponse requestStatus ->
            case requestStatus of
                Success data ->
                    ( { model
                        | status = requestStatus
                        , session = Session.withCredentials model.session (Just data.creds)
                      }
                    , Cmd.batch
                        [ Api.storeCredentials data.creds
                        , Models.Location.storeSchoolLocation data.location
                        , Navigation.rerouteTo model Navigation.Buses
                        ]
                    )

                _ ->
                    ( { model | status = requestStatus }
                    , Cmd.none
                    )


view : Model -> Int -> Element Msg
view model viewHeight =
    let
        spacer =
            el [] none

        errorCaption =
            if RemoteData.isFailure model.status then
                Just (Errors.InputError "" [])

            else
                Nothing
    in
    el [ width fill, height (px viewHeight) ]
        (column [ centerX, centerY, width (fill |> maximum 500), spacing 10, paddingXY 30 0 ]
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
                , errorCaption = errorCaption
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
                , errorCaption = errorCaption
                , value = model.form.password
                , onChange = UpdatedPassword
                , placeholder = Nothing
                , ariaLabel = "Password input"
                , icon = Nothing
                , newPassword = False
                }
            , viewError model.status
            , spacer
            , viewButton model
            , viewDivider
            , viewFooter
            , el [ height (fill |> minimum 100) ] none
            ]
        )


viewError : WebData SuccessfulLogin -> Element Msg
viewError status =
    case status of
        Failure error ->
            el []
                (Element.paragraph [ Font.color Colors.errorRed ]
                    [ text (Errors.loginErrorToString error)
                    ]
                )

        _ ->
            none


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
