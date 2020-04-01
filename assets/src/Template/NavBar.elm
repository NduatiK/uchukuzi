module Template.NavBar exposing (Model, Msg, init, maxHeight, update, viewHeader)

import Api
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Icons
import Route exposing (Route)
import Session
import Style
import StyledElement


maxHeight : Int
maxHeight =
    70


type Model
    = Model
        { dropdownVisible : Bool
        , session : Session.Session
        }


init : Session.Session -> Model
init session =
    Model { dropdownVisible = False, session = session }


internals model =
    case model of
        Model i ->
            i


type Msg
    = Logout
    | Dashboard
    | ToggleDropDown


viewHeader : Model -> Session.Session -> Maybe Route -> Element Msg
viewHeader model session route =
    case Session.getCredentials session of
        Nothing ->
            viewGuestHeader route

        Just cred ->
            viewLoggedInHeader model cred


viewGuestHeader : Maybe Route -> Element Msg
viewGuestHeader route =
    row
        [ Region.navigation
        , width fill
        , Background.color (rgb 1 1 1)
        , height (px 70)
        , Border.shadow { offset = ( 0, 0 ), size = 0, blur = 2, color = rgba 0 0 0 0.14 }
        , Element.inFront viewFlotillaLogo
        , height (px 71)
        ]
        [ viewBusesLogo
        , viewLoginOptions route
        ]


viewLoginOptions : Maybe Route -> Element Msg
viewLoginOptions route =
    let
        ghostAttrs =
            [ Background.color (rgba 0 0 0 0)
            , Font.color Colors.darkText
            ]

        signUp =
            StyledElement.navigationLink ghostAttrs
                { label = text "Sign up", route = Route.Signup }

        login =
            StyledElement.navigationLink
                (if route == Just Route.Signup then
                    ghostAttrs

                 else
                    []
                )
                { label = text "Login"
                , route = Route.Login Nothing
                }

        loginOptions =
            case route of
                Just (Route.Login _) ->
                    [ signUp ]

                Just Route.Signup ->
                    [ login ]

                _ ->
                    [ signUp, login ]
    in
    row [ alignRight, paddingXY 24 0, spacing 10 ]
        loginOptions


viewLoggedInHeader : Model -> Session.Cred -> Element Msg
viewLoggedInHeader model creds =
    row
        [ Region.navigation
        , width fill
        , Background.color (rgb 1 1 1)
        , height (px maxHeight)
        , Border.shadow { offset = ( 0, 0 ), size = 0, blur = 2, color = rgba 0 0 0 0.14 }
        , spacing 8
        , Element.inFront viewFlotillaLogo
        ]
        [ viewBusesLogo
        , el [ width (px 24) ] none
        , viewHeaderProfileData model creds
        , el [ width (px 1) ] none
        ]


viewBusesLogo : Element Msg
viewBusesLogo =
    let
        logo =
            image [ alignLeft, paddingXY 24 0, height (px 28), centerY ]
                { src = "images/logo.png", description = "Flotilla Logo" }
    in
    link []
        { label = logo, url = Route.href Route.Home }


viewFlotillaLogo : Element Msg
viewFlotillaLogo =
    image
        [ height (px 30), centerX, centerY, Style.mobileHidden ]
        { src = "images/logo-name.png", description = "Flotilla Name" }


viewHeaderProfileData : Model -> Session.Cred -> Element Msg
viewHeaderProfileData model cred =
    let
        dropdownVisible =
            .dropdownVisible (internals model)

        elementBelow =
            if dropdownVisible then
                column
                    [ width fill
                    , moveUp 8
                    , Border.shadow { offset = ( 0, 0 ), size = 0, blur = 5, color = rgba 0 0 0 0.14 }
                    ]
                    [ dropdownOption "Go to Dashboard" (Just Dashboard)
                    , dropdownOption "Settings" (Just Logout)
                    , dropdownOption "Logout" (Just Logout)
                    ]

            else
                none
    in
    row
        [ alignRight
        , below elementBelow
        ]
        [ el (Style.labelStyle ++ [ Font.color (rgb255 104 104 104) ]) (text cred.name)

        -- , el [ height (px 48), width (px 48), Background.color (rgb255 228 228 228), Border.rounded 24 ] Element.none
        , Input.button
            [ height (px 48)
            , width (px 48)
            ]
            { onPress = Just ToggleDropDown
            , label =
                Icons.chevronDown
                    (if dropdownVisible then
                        [ rotate pi ]

                     else
                        []
                    )
            }
        ]


dropdownOption optionText action =
    let
        alphaValue =
            1
    in
    Input.button
        [ Background.color Colors.white
        , alignRight
        , paddingXY 10 10
        , width fill
        , Border.shadow { offset = ( 0, 0 ), size = 0, blur = 2, color = rgba 0 0 0 0.24 }
        , Style.animatesAll
        , alpha alphaValue
        ]
        { onPress = action
        , label =
            el
                ([]
                    ++ Style.captionLabelStyle
                )
                (text optionText)
        }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        internalData =
            internals model
    in
    case msg of
        ToggleDropDown ->
            ( Model { internalData | dropdownVisible = not internalData.dropdownVisible }, Cmd.none )

        Dashboard ->
            ( model
            , Cmd.batch
                [ -- sendLogout
                  Route.rerouteTo internalData Route.Dashboard
                ]
            )

        Logout ->
            ( model
            , Cmd.batch
                [ -- sendLogout
                  Api.logout
                ]
            )
