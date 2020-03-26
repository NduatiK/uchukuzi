module Template.NavBar exposing (..)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import Icons
import Route exposing (Route)
import Session
import Style
import StyledElement


viewHeader : Session.Session -> Maybe Route -> Element msg
viewHeader session route =
    case Session.getCredentials session of
        Nothing ->
            viewGuestHeader route

        Just cred ->
            viewLoggedInHeader cred


viewGuestHeader : Maybe Route -> Element msg
viewGuestHeader route =
    row
        [ Region.navigation
        , width fill
        , Background.color (rgb 1 1 1)
        , height (px 70)
        , Border.shadow { offset = ( 0, 0 ), size = 0, blur = 2, color = rgba 0 0 0 0.14 }
        , Element.inFront viewFlotillaLogo
        ]
        [ viewBusesLogo
        , viewLoginOptions route
        ]


viewLoginOptions : Maybe Route -> Element msg
viewLoginOptions route =
    let
        ghostAttrs =
            [ Background.color (rgba 0 0 0 0)
            , Font.color Style.darkTextColor
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


viewLoggedInHeader : Session.Cred -> Element msg
viewLoggedInHeader creds =
    row
        [ Region.navigation
        , width fill
        , Background.color (rgb 1 1 1)
        , height (px 70)
        , Border.shadow { offset = ( 0, 0 ), size = 0, blur = 2, color = rgba 0 0 0 0.14 }
        , spacing 24
        , Element.inFront viewFlotillaLogo
        ]
        [ viewBusesLogo
        , viewHeaderProfileData creds
        ]


viewBusesLogo : Element msg
viewBusesLogo =
    let
        logo =
            image [ alignLeft, paddingXY 24 0, height (px 28), centerY ]
                { src = "images/logo.png", description = "Flotilla Logo" }
    in
    link []
        { label = logo, url = Route.href Route.Home }


viewFlotillaLogo : Element msg
viewFlotillaLogo =
    image
        [ height (px 30), centerX, centerY, Style.mobileHidden ]
        { src = "images/logo-name.png", description = "Flotilla Name" }


viewHeaderProfileData : Session.Cred -> Element msg
viewHeaderProfileData cred =
    row [ alignRight, paddingXY 24 0, spacing 16 ]
        [ el (Style.labelStyle ++ [ Font.color (rgb255 104 104 104) ]) (text cred.name)
        , el [ height (px 48), width (px 48), Background.color (rgb255 228 228 228), Border.rounded 24 ] Element.none

        -- , Icons.chevronDown []
        ]
