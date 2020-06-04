module Template.NavBar exposing (Model, Msg, hideNavBarMsg, init, isVisible, maxHeight, update, view)

import Api
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Icons
import Navigation exposing (Route)
import Session
import Style exposing (edges)
import StyledElement
import Task


maxHeight : Int
maxHeight =
    70


type Model
    = Model
        { dropdownVisible : Bool
        }


init : Session.Session -> Model
init session =
    Model { dropdownVisible = False }


internals model =
    case model of
        Model i ->
            i



-- UPDATE


type Msg
    = Logout
    | ToggleDropDown
    | HideDropDown


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        internalData =
            internals model
    in
    case msg of
        ToggleDropDown ->
            ( Model { internalData | dropdownVisible = not internalData.dropdownVisible }, Cmd.none )

        HideDropDown ->
            ( Model { internalData | dropdownVisible = False }, Cmd.none )

        Logout ->
            ( model
            , Cmd.batch
                [ -- sendLogout
                  Api.logout
                ]
            )


view : Model -> Session.Session -> Maybe Route -> Element Msg
view model session route =
    row
        [ Region.navigation
        , width fill
        , Background.color (rgb 1 1 1)
        , height (px maxHeight)
        , Border.widthEach { edges | bottom = 1 }
        , Border.color (Colors.withAlpha Colors.black 0.2)
        , spacing 8
        , Element.inFront viewFlotillaLogo
        ]
        (case Session.getCredentials session of
            Nothing ->
                viewGuestHeader route

            Just cred ->
                viewLoggedInHeader model cred
        )


viewGuestHeader : Maybe Route -> List (Element Msg)
viewGuestHeader route =
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
                { label = text "Sign up", route = Navigation.Signup }

        login =
            StyledElement.navigationLink
                (if route == Just Navigation.Signup then
                    ghostAttrs

                 else
                    []
                )
                { label = text "Login"
                , route = Navigation.Login Nothing
                }

        loginOptions =
            case route of
                Just (Navigation.Login _) ->
                    [ signUp ]

                Just Navigation.Signup ->
                    [ login ]

                _ ->
                    [ signUp, login ]
    in
    row [ alignRight, paddingXY 24 0, spacing 10 ]
        loginOptions


viewLoggedInHeader : Model -> Session.Cred -> List (Element Msg)
viewLoggedInHeader model creds =
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
        { label = logo, url = Navigation.href Navigation.Home }


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
                    , Border.shadow { offset = ( 0, 0 ), size = 0, blur = 5, color = rgba 0 0 0 0.14 }
                    , Border.rounded 5
                    , Border.width 1
                    , Border.color (Colors.withAlpha Colors.darkness 0.3)
                    , Background.color Colors.white
                    , clip
                    , mouseOver
                        [ Border.color (Colors.withAlpha Colors.darkness 1)
                        ]
                    , Style.nonClickThrough
                    ]
                    [ dropdownOption "Logout" (Just Logout)
                    ]

            else
                none
    in
    row
        [ alignRight
        , inFront
            (column [ width fill, paddingXY 10 0, Style.clickThrough ]
                [ el [ height (px 36), Style.clickThrough ] none
                , elementBelow
                ]
            )
        ]
        [ el (Style.labelStyle ++ [ Font.color (rgb255 104 104 104) ]) (text cred.name)

        -- , el [ height (px 48), width (px 48), Background.color (rgb255 228 228 228), Border.rounded 24 ] Element.none
        , Input.button
            [ height (px 48)
            , width (px 48)
            , alignTop
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

        -- , Style.animatesAll
        , alpha alphaValue
        , mouseOver
            [ Background.color (Colors.withAlpha Colors.darkness 0.3)
            , Border.color (Colors.withAlpha Colors.darkness 1)
            ]
        ]
        { onPress = action
        , label =
            el
                ([]
                    ++ Style.captionStyle
                    ++ [ Font.size 15 ]
                )
                (text optionText)
        }


isVisible (Model model) =
    model.dropdownVisible


hideNavBarMsg =
    Task.succeed HideDropDown |> Task.perform identity
