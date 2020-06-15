module Layout.NavBar exposing (Model, Msg, hideNavBar, init, isVisible, maxHeight, update, view)

import Api
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Html.Events as HEvents
import Icons
import Json.Decode as Json
import Models.Notification exposing (Notification)
import Navigation exposing (Route)
import Session
import Style exposing (edges)
import StyledElement
import TypedSvg exposing (svg)
import TypedSvg.Attributes exposing (stroke, viewBox)
import TypedSvg.Types exposing (Paint(..), Transform(..))
import Views.NotificationView as NotificationView


maxHeight : Int
maxHeight =
    70


type Model
    = Model Internals


type alias Internals =
    { accountDropdownVisible : Bool
    , notificationsVisible : Bool
    , shouldClearNotifications : Bool
    }


init : Model
init =
    Model
        { accountDropdownVisible = False
        , notificationsVisible = False
        , shouldClearNotifications = False
        }


internals : Model -> Internals
internals model =
    case model of
        Model i ->
            i



-- UPDATE


type Msg
    = NoOp
      -----------
    | Logout
    | OpenSettings
    | RedirectTo String
      -----------
    | ToggleAccountDropDown
    | ToggleNotificationsDropDown
      -----------
    | HideDropDown
    | ClearNotifications


update : Msg -> Model -> Session.Session -> ( Model, Cmd Msg, Bool )
update msg model session =
    let
        internalData =
            internals model
    in
    case msg of
        NoOp ->
            ( model, Cmd.none, False )

        ToggleAccountDropDown ->
            ( Model
                { internalData
                    | accountDropdownVisible = not internalData.accountDropdownVisible
                    , notificationsVisible = False
                }
            , Cmd.none
            , False
            )

        HideDropDown ->
            ( Model
                { internalData
                    | accountDropdownVisible = False
                    , notificationsVisible = False
                }
            , Cmd.none
            , False
            )

        ToggleNotificationsDropDown ->
            ( Model
                { internalData
                    | accountDropdownVisible = False
                    , notificationsVisible = not internalData.notificationsVisible
                }
            , Cmd.none
            , False
            )

        RedirectTo urlString ->
            ( model
            , Navigation.rerouteToString { session = session } urlString
            , False
            )

        Logout ->
            ( Model
                { internalData
                    | accountDropdownVisible = False
                    , notificationsVisible = False
                }
            , Cmd.batch
                [ Api.logout
                ]
            , False
            )

        OpenSettings ->
            ( Model
                { internalData
                    | accountDropdownVisible = False
                    , notificationsVisible = False
                }
            , Navigation.rerouteTo { session = session } Navigation.Settings
            , False
            )

        ClearNotifications ->
            ( Model
                { internalData
                    | shouldClearNotifications = True
                }
            , Cmd.none
            , True
            )



-- VIEW


view : Model -> Session.Session -> Maybe Route -> List Notification -> Element Msg
view model session route notifications =
    let
        viewFlotillaLogo : Element Msg
        viewFlotillaLogo =
            image
                [ height (px 30), centerX, centerY, Style.mobileHidden ]
                { src = "images/logo-name.png", description = "Flotilla Name" }

        viewBusesLogo : Element Msg
        viewBusesLogo =
            let
                logo =
                    image [ alignLeft, paddingXY 24 0, height (px 28), centerY ]
                        { src = "images/logo.png", description = "Flotilla Logo" }
            in
            link []
                { label = logo, url = Navigation.href Navigation.Home }
    in
    row
        [ Region.navigation
        , width fill
        , Background.color (rgb 1 1 1)
        , height (px maxHeight)
        , Border.widthEach { edges | bottom = 1 }
        , Border.color (Colors.withAlpha Colors.black 0.2)
        , spacing 8
        , Element.inFront viewFlotillaLogo
        , Style.zIndex 10
        ]
        [ viewBusesLogo
        , el [ width (px 24) ] none
        , case Session.getCredentials session of
            Nothing ->
                viewGuestHeader route

            Just cred ->
                viewLoggedInHeader model cred notifications
        ]


viewGuestHeader : Maybe Route -> Element Msg
viewGuestHeader route =
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


viewLoggedInHeader : Model -> Session.Credentials -> List Notification -> Element Msg
viewLoggedInHeader model creds notifications =
    let
        { accountDropdownVisible, notificationsVisible } =
            internals model

        rightOffset =
            if accountDropdownVisible then
                16

            else if notificationsVisible then
                12 + 36 + 16 + 12

            else
                0

        elementBelow =
            if accountDropdownVisible then
                viewDropDownList [ onClickWithoutPropagation NoOp ]
                    [ paragraph [ paddingXY 15 15, Font.size 14 ]
                        [ el [] (text "Signed in as ")
                        , el [ Font.bold ] (text creds.name)
                        ]
                    , dropdownOption Icons.settings "Settings" (Just OpenSettings)
                    , dropdownOption Icons.exit "Logout" (Just Logout)
                    ]

            else if notificationsVisible then
                viewDropDownList
                    [ width (fill |> maximum 300)
                    , onClickWithoutPropagation NoOp
                    ]
                    [ row
                        [ width fill
                        , paddingXY 15 0
                        , Border.shadow { offset = ( 0, 0 ), size = 0, blur = 2, color = rgba 0 0 0 0.24 }
                        ]
                        [ el
                            [ paddingXY 0 15
                            , Font.bold
                            , Font.size 14
                            ]
                            (text "Notifications")
                        , el [ alignRight ]
                            (if notifications /= [] then
                                StyledElement.plainButton
                                    [ Background.color Colors.white
                                    , centerY
                                    , Font.color Colors.purple
                                    , Font.size 15
                                    , mouseOver [ Background.color Colors.backgroundPurple ]
                                    , Border.rounded 4
                                    , paddingXY 8 4
                                    , moveDown 2
                                    ]
                                    { label =
                                        row [ centerX ]
                                            [ el [ centerY ] (text "Clear")
                                            ]
                                    , onPress = Just ClearNotifications
                                    }

                             else
                                none
                            )
                        ]
                    , NotificationView.view notifications RedirectTo
                    ]

            else
                none
    in
    row
        [ alignRight
        , width fill
        , inFront
            (column [ width fill, paddingEach { edges | right = rightOffset }, Style.clickThrough, Style.animatesAll ]
                [ el [ height (px 54), Style.clickThrough ] none
                , elementBelow
                ]
            )
        ]
        [ el
            [ alignRight
            , onClickWithoutPropagation ToggleNotificationsDropDown
            ]
            (NotificationView.icon notifications NoOp)
        , el [ width (px 12) ] none
        , viewProfileIcon
            (onClickWithoutPropagation ToggleAccountDropDown)
        , el [ width (px 16) ] none
        ]


viewProfileIcon : Attribute Msg -> Element Msg
viewProfileIcon clickAttr =
    Input.button
        [ height (px 48)
        , alignTop
        , alignRight
        , clickAttr
        ]
        { onPress = Nothing
        , label =
            el [ centerY, padding 6 ]
                (el
                    [ width (px 36)
                    , height (px 36)
                    , Border.rounded 18
                    , Background.color Colors.backgroundGreen
                    ]
                    (Icons.person [ centerX, centerY, Colors.fillDarkness, alpha 1 ])
                )
        }


viewDropDownList : List (Attribute msg) -> List (Element msg) -> Element msg
viewDropDownList attrs views =
    column
        ([ alignRight
         , Border.shadow
            { offset = ( 0, 3 )
            , size = 2
            , blur = 5
            , color = rgba 0 0 0 0.14
            }
         , spacing 1
         , Border.rounded 3
         , Border.width 1
         , Border.color (Colors.withAlpha Colors.black 0.3)
         , Background.color Colors.white
         , Style.nonClickThrough
         , above
            dropdownTriangle
         ]
            ++ attrs
        )
        views


dropdownTriangle : Element msg
dropdownTriangle =
    let
        path =
            [ ( 0, 24 ), ( 12, 12 ), ( 24, 24 ) ]
    in
    el [ width (px 42), height (px 24), Style.zIndex 11, alignRight, paddingXY 5 0 ]
        (html <|
            svg [ viewBox 0 0 24 24 ]
                [ TypedSvg.polygon
                    [ TypedSvg.Attributes.fill
                        (Paint <|
                            Colors.toSVGColor Colors.white
                        )
                    , TypedSvg.Attributes.points
                        path
                    ]
                    []
                , TypedSvg.polyline
                    [ TypedSvg.Attributes.fill
                        (Paint <|
                            Colors.toSVGColor Colors.white
                        )
                    , TypedSvg.Attributes.stroke <|
                        Paint <|
                            (Colors.black
                                |> Colors.toSVGColor
                                |> Colors.svgColorwithAlpha 0.3
                            )
                    , TypedSvg.Attributes.points
                        path
                    , TypedSvg.Attributes.strokeLinejoin TypedSvg.Types.StrokeLinejoinRound
                    ]
                    []
                ]
        )


dropdownOption : (List (Attribute msg) -> Element msg) -> String -> Maybe msg -> Element msg
dropdownOption icon optionText action =
    let
        alphaValue =
            1
    in
    Input.button
        [ Background.color Colors.white
        , paddingXY 15 10
        , width fill
        , Border.shadow { offset = ( 0, 0 ), size = 0, blur = 2, color = rgba 0 0 0 0.24 }
        , alpha alphaValue
        , Colors.fillWhiteOnHover
        , if action == Nothing then
            mouseOver []

          else
            mouseOver
                [ Background.color (Colors.withAlpha Colors.purple 1)
                , Border.color (Colors.withAlpha Colors.purple 1)
                , Font.color Colors.white
                ]
        ]
        { onPress = action
        , label =
            row [ spacing 4, centerY ]
                [ icon
                    [ Colors.fillDarkness
                    , width (px 17)
                    , height (px 17)
                    , centerY
                    , alpha 1
                    ]
                , el
                    [ Font.size 16
                    , Font.medium
                    , centerY
                    , moveDown 1
                    ]
                    (text optionText)
                ]
        }


isVisible : Model -> Bool
isVisible (Model model) =
    model.accountDropdownVisible || model.notificationsVisible


hideNavBar : Msg
hideNavBar =
    HideDropDown


onClickWithoutPropagation : Msg -> Attribute Msg
onClickWithoutPropagation msg =
    htmlAttribute
        (HEvents.stopPropagationOn "click"
            (Json.succeed ( msg, True ))
        )
