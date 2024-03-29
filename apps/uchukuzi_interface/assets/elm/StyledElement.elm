module StyledElement exposing
    ( button
    , buttonLink
    , checkboxIcon
    , dropDown
    , emailInput
    , failureButton
    , ghostButton
    , ghostButtonLink
    , ghostButtonWithCustom
    , googleMap
    , hoverButton
    , iconButton
    , inputStyle
    , multilineInput
    , navigationLink
    , numberInput
    , passwordInput
    , plainButton
    , textInput
    , textLink
    , textStack
    , textStackWithColor
    , textStackWithSpacing
    , unstyledIconButton
    , wrappedInput
    )

import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Errors exposing (InputError)
import Html exposing (node)
import Html.Attributes
import Html.Events as Events
import Icons exposing (IconBuilder)
import Json.Decode as Decode
import Navigation
import Regex
import Style exposing (..)
import StyledElement.DropDown as Dropdown


customTextStack : String -> String -> Int -> Color -> Element msg
customTextStack title body spacing highlightColor =
    column (Style.header2Style ++ [ width fill, Font.color Colors.black ])
        [ paragraph [ alignLeft, paddingXY 0 spacing ] [ text title ]
        , paragraph [ alignLeft, Font.color highlightColor ] [ text body ]
        ]


textStackWithColor : String -> String -> Color -> Element msg
textStackWithColor title body highlightColor =
    customTextStack title body 0 highlightColor


textStackWithSpacing : String -> String -> Int -> Element msg
textStackWithSpacing title body spacing =
    customTextStack title body spacing Colors.darkGreen


textStack : String -> String -> Element msg
textStack title body =
    textStackWithSpacing title body 0


navigationLink : List (Attribute msg) -> { label : Element msg, route : Navigation.Route } -> Element msg
navigationLink attrs config =
    Element.link
        (defaultFontFace
            ++ [ paddingXY 27 10
               , Font.size 19
               , Font.color Colors.purple
               , Element.mouseOver
                    [ alpha 0.9
                    ]

               --    , Font.medium
               ]
            ++ defaultFontFace
            ++ attrs
        )
        { url = Navigation.href config.route
        , label = config.label
        }


ghostButtonLink :
    List (Attribute msg)
    -> { title : String, route : Navigation.Route }
    -> Element msg
ghostButtonLink attrs { title, route } =
    buttonLink
        ([ Border.width 3, Border.color Colors.purple, Background.color Colors.white ] ++ attrs)
        { label =
            row [ spacing 8 ]
                [ el [ centerY, Font.color Colors.purple ] (text title)
                , Icons.chevronDown [ alpha 1, Colors.fillPurple, rotate (-pi / 2), centerY ]
                ]
        , route = route
        }


buttonLink :
    List (Attribute msg)
    -> { label : Element msg, route : Navigation.Route }
    -> Element msg
buttonLink attributes config =
    Element.link
        ([ Background.color Colors.purple
         , htmlAttribute (Html.Attributes.class "button-link")

         -- Primarily controlled by css
         , height (px 46)
         , Font.color (Element.rgb 1 1 1)
         , Font.size 18
         , Border.rounded 3
         , Style.animatesAll
         , Style.cssResponsive
         , Element.mouseOver
            [ moveUp 1
            , Border.shadow { offset = ( 0, 4 ), size = 0, blur = 8, color = rgba 0 0 0 0.14 }
            ]
         ]
            ++ Style.defaultFontFace
            ++ attributes
        )
        { url = Navigation.href config.route
        , label = el [ centerY ] config.label
        }


textLink : List (Attribute msg) -> { label : Element msg, route : Navigation.Route } -> Element msg
textLink attributes config =
    link
        (defaultFontFace
            ++ [ Font.color Colors.purple
               , Font.size 18
               , Border.rounded 3
               , Element.mouseOver
                    [ alpha 0.9 ]
               ]
            ++ attributes
        )
        { url = Navigation.href config.route
        , label = config.label
        }


plainButton :
    List (Attribute msg)
    -> { label : Element msg, onPress : Maybe msg }
    -> Element msg
plainButton attributes config =
    Input.button
        attributes
        { onPress = config.onPress
        , label = config.label
        }


button :
    List (Attribute msg)
    -> { label : Element msg, onPress : Maybe msg }
    -> Element msg
button attributes config =
    plainButton
        ([ Background.color Colors.purple
         , height (px 46)
         , Font.color (Element.rgb 1 1 1)
         , Font.size 18
         , Style.cssResponsive
         , Border.rounded 3
         , Style.animatesAll
         , Element.mouseOver
            [ moveUp 1
            , Border.shadow { offset = ( 0, 4 ), size = 0, blur = 8, color = rgba 0 0 0 0.14 }
            ]
         ]
            ++ Style.defaultFontFace
            ++ attributes
        )
        config


hoverButton :
    List (Attribute msg)
    -> { title : String, onPress : Maybe msg, icon : Maybe (IconBuilder msg) }
    -> Element msg
hoverButton attrs { title, onPress, icon } =
    button
        ([ Background.color Colors.white
         , centerY
         , Font.color Colors.purple
         , mouseOver [ Background.color Colors.backgroundPurple ]
         ]
            ++ attrs
        )
        { label =
            row [ spacing 8, centerX ]
                [ Maybe.withDefault (always none) icon [ Colors.fillPurple ]
                , el [ centerY ] (text title)
                ]
        , onPress = onPress
        }


failureButton :
    List (Attribute msg)
    -> { title : String, onPress : Maybe msg }
    -> Element msg
failureButton attrs { title, onPress } =
    button
        (Background.color Colors.errorRed :: attrs)
        { label =
            row [ spacing 8 ]
                [ Icons.refresh [ Colors.fillWhite, alpha 1 ]
                , el [ centerY ] (text title)
                ]
        , onPress = onPress
        }


ghostButtonWithCustom :
    List (Attribute msg)
    -> List (Attribute msg)
    -> { title : String, onPress : Maybe msg, icon : Icons.IconBuilder msg }
    -> Element msg
ghostButtonWithCustom attrs innerAttrs { title, onPress, icon } =
    button
        ([ Border.width 3, Border.color Colors.purple, Background.color Colors.white ] ++ attrs)
        { label =
            row [ spacing 8 ]
                [ icon ([ alpha 1, Colors.fillPurple ] ++ innerAttrs)
                , el ([ centerY, Font.color Colors.purple ] ++ innerAttrs) (text title)
                ]
        , onPress = onPress
        }


ghostButton :
    List (Attribute msg)
    -> { title : String, onPress : Maybe msg, icon : Icons.IconBuilder msg }
    -> Element msg
ghostButton attrs config =
    ghostButtonWithCustom attrs [] config


unstyledIconButton :
    List (Attribute msg)
    ->
        { icon : IconBuilder msg
        , iconAttrs : List (Attribute msg)
        , onPress : Maybe msg
        }
    -> Element msg
unstyledIconButton attributes { onPress, iconAttrs, icon } =
    Input.button
        ([ padding 12
         , alignBottom
         , Style.animatesAll
         , Element.mouseOver
            [ moveUp 1
            , Border.shadow { offset = ( 2, 4 ), size = 0, blur = 8, color = rgba 0 0 0 0.14 }
            ]
         ]
            ++ attributes
        )
        { onPress = onPress
        , label = icon iconAttrs
        }


iconButton :
    List (Attribute msg)
    ->
        { icon : IconBuilder msg
        , iconAttrs : List (Attribute msg)
        , onPress : Maybe msg
        }
    -> Element msg
iconButton attributes { onPress, iconAttrs, icon } =
    Input.button
        ([ padding 12
         , alignBottom
         , Background.color Colors.purple
         , Border.rounded 8
         , Style.animatesAll
         , Element.mouseOver
            [ moveUp 1
            , Border.shadow { offset = ( 2, 4 ), size = 0, blur = 8, color = rgba 0 0 0 0.14 }
            ]
         ]
            ++ attributes
        )
        { onPress = onPress
        , label = icon iconAttrs
        }


paddingForIcon icon =
    if icon /= Nothing then
        paddingEach { edges | left = 48, right = 12, top = 12, bottom = 12 }

    else
        paddingXY 12 12


textInput :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , errorCaption : Maybe (InputError e)
        , value : String
        , onChange : String -> msg
        , placeholder : Maybe (Input.Placeholder msg)
        , ariaLabel : String
        , icon : Maybe (IconBuilder msg)
        }
    -> Element msg
textInput attributes { title, caption, errorCaption, value, onChange, placeholder, ariaLabel, icon } =
    let
        input =
            Input.text
                (Style.labelStyle
                    ++ [ centerY
                       , Border.width 0
                       , Background.color (rgba 0 0 0 0)
                       , id (String.replace " " "-" (String.toLower ariaLabel))
                       , paddingForIcon icon
                       ]
                )
                { onChange = onChange
                , text = value
                , placeholder = placeholder
                , label = Input.labelHidden ariaLabel
                }
    in
    wrappedInput input title caption errorCaption icon attributes []


multilineInput :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , errorCaption : Maybe (InputError e)
        , value : String
        , onChange : String -> msg
        , placeholder : Maybe (Input.Placeholder msg)
        , ariaLabel : String
        }
    -> Element msg
multilineInput attributes { title, caption, errorCaption, value, onChange, placeholder, ariaLabel } =
    let
        input =
            Input.multiline
                (Style.labelStyle ++ [ height fill, centerY, Border.width 0, Background.color (rgba 0 0 0 0), id (String.replace " " "-" (String.toLower ariaLabel)) ])
                { onChange = onChange
                , text = value
                , placeholder = placeholder
                , label = Input.labelHidden ariaLabel
                , spellcheck = True
                }
    in
    wrappedInput input title caption errorCaption Nothing attributes []


emailInput :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , errorCaption : Maybe (InputError e)
        , value : String
        , onChange : String -> msg
        , placeholder : Maybe (Input.Placeholder msg)
        , ariaLabel : String
        , icon : Maybe (IconBuilder msg)
        }
    -> Element msg
emailInput attributes { title, caption, errorCaption, value, onChange, placeholder, ariaLabel, icon } =
    let
        input =
            Input.email
                (Style.labelStyle ++ [ paddingForIcon icon, centerY, Border.width 0, Background.color (rgba 0 0 0 0), id (String.replace " " "-" (String.toLower ariaLabel)) ])
                { onChange = onChange
                , text = value
                , placeholder = placeholder
                , label = Input.labelHidden ariaLabel
                }
    in
    wrappedInput input title caption errorCaption icon attributes []


dropDown :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , errorCaption : Maybe (InputError e)
        , options : List item
        , ariaLabel : String
        , icon : Maybe (IconBuilder msg)
        , dropDownMsg : Dropdown.Msg item -> msg
        , onSelect : Maybe item -> msg
        , toString : item -> String
        , dropdownState : Dropdown.State item
        , isLoading : Bool
        , prompt : Maybe String
        }
    -> ( Element msg, Dropdown.Config item msg, List item )
dropDown attributes { title, caption, dropdownState, dropDownMsg, onSelect, errorCaption, options, ariaLabel, icon, toString, isLoading, prompt } =
    let
        config : Dropdown.Config item msg
        config =
            Dropdown.dropDownConfig dropDownMsg onSelect toString icon isLoading (Maybe.withDefault "Pick one" prompt) inputStyle

        input =
            Dropdown.view config dropdownState options

        body =
            wrappedInput input title caption errorCaption Nothing (attributes ++ [ Border.width 0 ]) []
    in
    ( body, config, options )


passwordInput :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , errorCaption : Maybe (InputError e)
        , value : String
        , onChange : String -> msg
        , placeholder : Maybe (Input.Placeholder msg)
        , ariaLabel : String
        , icon : Maybe (IconBuilder msg)
        , newPassword : Bool
        }
    -> Element msg
passwordInput attributes { title, caption, errorCaption, value, onChange, placeholder, ariaLabel, icon, newPassword } =
    let
        passwordBoxBuilder =
            if newPassword then
                Input.newPassword

            else
                Input.currentPassword

        input =
            passwordBoxBuilder
                ([ paddingForIcon icon, Border.width 0, Background.color (rgba 0 0 0 0), id (String.replace " " "-" (String.toLower ariaLabel)) ]
                    ++ Style.labelStyle
                )
                { onChange = onChange
                , text = value
                , placeholder = placeholder
                , label = Input.labelHidden ariaLabel
                , show = False
                }
    in
    wrappedInput input title caption errorCaption icon attributes []


errorBorder : Bool -> List (Attribute msg)
errorBorder hideBorder =
    if hideBorder then
        []

    else
        [ Border.color Colors.errorRed, Border.solid, Border.width 2 ]


checkboxIcon : Bool -> Element msg
checkboxIcon checked =
    if checked then
        Icons.check [ height (px 14), width (px 14) ]

    else
        Input.defaultCheckbox checked


onKeyDown :
    { increase : Maybe msg, decrease : Maybe msg }
    -> Attribute msg
onKeyDown { increase, decrease } =
    let
        stringToKey str =
            case str of
                "ArrowUp" ->
                    increase
                        |> Maybe.map Decode.succeed
                        |> Maybe.withDefault (Decode.fail "not used key")

                "ArrowDown" ->
                    decrease
                        |> Maybe.map Decode.succeed
                        |> Maybe.withDefault (Decode.fail "not used key")

                _ ->
                    Decode.fail "not used key"

        keyDecoder =
            Decode.field "key" Decode.string
                |> Decode.andThen stringToKey
    in
    Events.on "keydown" keyDecoder
        |> htmlAttribute


numberInput :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , errorCaption : Maybe (InputError e)
        , value : Int
        , onChange : Int -> msg
        , placeholder : Maybe (Input.Placeholder msg)
        , ariaLabel : String
        , icon : Maybe (IconBuilder msg)
        , minimum : Maybe Int
        , maximum : Maybe Int
        }
    -> Element msg
numberInput attributes { title, caption, errorCaption, value, onChange, placeholder, ariaLabel, icon, minimum, maximum } =
    let
        increase =
            case maximum of
                Nothing ->
                    Just (onChange (value + 1))

                Just max ->
                    if (value + 1) > max then
                        Nothing

                    else
                        Just (onChange (value + 1))

        decrease =
            case minimum of
                Nothing ->
                    Just (onChange (value - 1))

                Just min ->
                    if (value - 1) < min then
                        Nothing

                    else
                        Just (onChange (value - 1))

        userReplace : String -> (Regex.Match -> String) -> String -> String
        userReplace userRegex replacer string =
            case Regex.fromString userRegex of
                Nothing ->
                    string

                Just regex ->
                    Regex.replace regex replacer string

        onlyDigits str =
            userReplace "[^\\d]" (\_ -> "") str

        onChangeWithMaxAndMin =
            let
                minimumValue =
                    Maybe.withDefault 0 minimum

                maximumValue =
                    Maybe.withDefault 100000 maximum
            in
            onlyDigits >> String.toInt >> Maybe.withDefault value >> Basics.clamp minimumValue maximumValue >> onChange

        textField =
            Input.text
                (Style.labelStyle
                    ++ [ paddingForIcon icon
                       , centerY
                       , Border.width 0
                       , Background.color (rgba 0 0 0 0)
                       , id (String.replace " " "-" (String.toLower ariaLabel))
                       , onKeyDown { increase = increase, decrease = decrease }
                       ]
                )
                { onChange = onChangeWithMaxAndMin
                , text = String.fromInt value
                , placeholder = placeholder
                , label = Input.labelHidden ariaLabel
                }

        body : Element msg
        body =
            wrappedInput textField
                title
                caption
                errorCaption
                icon
                attributes
                [ Input.button []
                    { label = Icons.subtract [ width <| px 24, height <| px 24 ]
                    , onPress = decrease
                    }
                , el [ Background.color (rgba 0 0 0 0.12), width <| px 1, height <| px 20 ] none
                , Input.button []
                    { label = Icons.add [ width <| px 24, height <| px 24 ]
                    , onPress = increase
                    }
                , el [ width <| px 0, height <| px 20 ] none
                ]
    in
    body


googleMap : List (Attribute msg) -> Element msg
googleMap mapClasses =
    el
        ([ height fill
         , width fill
         , Background.color Colors.semiDarkness
         , Border.color Colors.white
         , Border.width 2
         , padding 2
         ]
            ++ mapClasses
        )
        (html (node "gmap" [ Html.Attributes.id "google-map" ] []))


{-| wrappedInput input title caption errorCaption icon attributes trailingElements
-}
wrappedInput : Element msg -> String -> Maybe String -> Maybe (InputError e) -> Maybe (IconBuilder msg) -> List (Attribute msg) -> List (Element msg) -> Element msg
wrappedInput input title caption errorCaption icon attributes trailingElements =
    let
        captionLabel =
            case caption of
                Just captionText ->
                    Element.paragraph captionStyle [ text captionText ]

                Nothing ->
                    none

        errorCaptionLabel =
            errorCaption
                |> Maybe.map
                    (\e ->
                        case Errors.unwrapInputError e of
                            Just errors ->
                                Element.paragraph Style.errorStyle (List.map text errors)

                            Nothing ->
                                none
                    )
                |> Maybe.withDefault none

        textBoxIcon =
            case icon of
                Just iconElement ->
                    iconElement [ centerY, paddingEach { edges | left = 12 } ]

                Nothing ->
                    none

        viewTitle =
            if title /= "" then
                el Style.labelStyle (text title)

            else
                none
    in
    column
        (spacing 6 :: width fill :: height shrink :: attributes)
        [ viewTitle
        , el
            (spacing 12
                :: width fill
                :: centerY
                :: inFront textBoxIcon
                :: inFront (row [ spacing 12, height fill, alignRight ] trailingElements)
                :: inputStyle
                ++ errorBorder (errorCaption == Nothing)
            )
            input
        , captionLabel
        , errorCaptionLabel
        ]


inputStyle : List (Attribute msg)
inputStyle =
    -- underlinedTextFieldStyle
    borderTextFieldStyle


borderTextFieldStyle : List (Attribute msg)
borderTextFieldStyle =
    [ Background.color Colors.lightGrey
    , Border.color (Colors.withAlpha Colors.darkness 0.3)
    , Border.width 1
    , Border.rounded 5
    , Font.size 16
    , height
        (fill
            |> minimum 46
        )
    ]
        ++ defaultFontFace


underlinedTextFieldStyle : List (Attribute msg)
underlinedTextFieldStyle =
    [ Background.color (rgb255 245 245 245)
    , Border.color Colors.darkGreen
    , Border.widthEach
        { bottom = 2
        , left = 0
        , right = 0
        , top = 0
        }
    , Border.solid
    , Font.size 16
    , height
        (fill
            |> minimum 46
        )
    ]
        ++ defaultFontFace
