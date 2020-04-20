module StyledElement exposing
    ( button
    , buttonLink
    , checkboxIcon
    , dropDown
    , emailInput
    , googleMap
    , iconButton
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
    , toDropDownView
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
import Html.Attributes exposing (id)
import Http
import Icons exposing (IconBuilder)
import Json.Encode as Encode
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


textInput :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , errorCaption : Maybe InputError
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
                (Style.labelStyle ++ [ centerY, Border.width 0, Background.color (rgba 0 0 0 0) ])
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
        , errorCaption : Maybe InputError
        , value : String
        , onChange : String -> msg
        , placeholder : Maybe (Input.Placeholder msg)
        , ariaLabel : String
        , icon : Maybe (IconBuilder msg)
        }
    -> Element msg
multilineInput attributes { title, caption, errorCaption, value, onChange, placeholder, ariaLabel, icon } =
    let
        input =
            Input.multiline
                (Style.labelStyle ++ [ height fill, centerY, Border.width 0, Background.color (rgba 0 0 0 0) ])
                { onChange = onChange
                , text = value
                , placeholder = placeholder
                , label = Input.labelHidden ariaLabel
                , spellcheck = True
                }
    in
    wrappedInput input title caption errorCaption icon attributes []


emailInput :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , errorCaption : Maybe InputError
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
                (Style.labelStyle ++ [ centerY, Border.width 0, Background.color (rgba 0 0 0 0) ])
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
        , errorCaption : Maybe InputError
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
            Dropdown.dropDownConfig dropDownMsg onSelect toString icon isLoading (Maybe.withDefault "Pick one" prompt)

        input =
            Dropdown.view config dropdownState options

        body =
            wrappedInput input title caption errorCaption Nothing (attributes ++ [ Border.width 0 ]) []
    in
    ( body, config, options )


toDropDownView : ( Element msg, Dropdown.Config item msg, List item ) -> Element msg
toDropDownView aDropdown =
    case aDropdown of
        ( view, _, _ ) ->
            view


passwordInput :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , errorCaption : Maybe InputError
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
                ([ Border.width 0, Background.color (rgba 0 0 0 0) ]
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


{-| wrappedInput input title caption errorCaption icon attributes trailingElements
-}
wrappedInput : Element msg -> String -> Maybe String -> Maybe InputError -> Maybe (IconBuilder msg) -> List (Attribute msg) -> List (Element msg) -> Element msg
wrappedInput input title caption errorCaption icon attributes trailingElements =
    let
        captionLabel =
            case caption of
                Just captionText ->
                    Element.paragraph captionLabelStyle [ text captionText ]

                Nothing ->
                    none

        errorCaptionLabel =
            case errorCaption of
                Just (Errors.InputError errors) ->
                    Element.paragraph Style.errorStyle (List.map text errors)

                -- Just (Ser errors) ->
                --     Element.paragraph (Style.labelStyle ++ [ Font.color Style.error ]) (List.map text errors)
                _ ->
                    -- Nothing ->
                    none

        textBoxIcon =
            case icon of
                Just iconElement ->
                    iconElement [ centerY, paddingEach { edges | left = 12 } ]

                Nothing ->
                    none
    in
    Element.column
        ([ spacing 6
         , width fill
         , height
            shrink
         ]
            ++ attributes
        )
        [ if title /= "" then
            el Style.labelStyle (text title)

          else
            none
        , row
            (spacing 12 :: width fill :: centerY :: Style.inputStyle ++ errorBorder (errorCaption == Nothing))
            ([ textBoxIcon
             , input
             ]
                ++ trailingElements
            )
        , captionLabel
        , errorCaptionLabel
        ]


checkboxIcon : Bool -> Element msg
checkboxIcon checked =
    if checked then
        Icons.check [ height (px 14), width (px 14) ]

    else
        Input.defaultCheckbox checked


numberInput :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , errorCaption : Maybe InputError
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
                (Style.labelStyle ++ [ centerY, Border.width 0, Background.color (rgba 0 0 0 0) ])
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
                    , onPress =
                        case minimum of
                            Nothing ->
                                Just (onChange (value - 1))

                            Just min ->
                                if (value - 1) < min then
                                    Nothing

                                else
                                    Just (onChange (value - 1))
                    }
                , el [ Background.color (rgba 0 0 0 0.12), width <| px 1, height <| px 20 ] none
                , Input.button []
                    { label = Icons.add [ width <| px 24, height <| px 24 ]
                    , onPress =
                        case maximum of
                            Nothing ->
                                Just (onChange (value + 1))

                            Just max ->
                                if (value + 1) > max then
                                    Nothing

                                else
                                    Just (onChange (value + 1))
                    }
                , el [ width <| px 0, height <| px 20 ] none
                ]
    in
    body


googleMap mapClasses =
    el
        ([ height fill
         , width fill
         , htmlAttribute (id "google-map")
         , Background.color (rgb255 237 237 237)
         ]
            ++ mapClasses
        )
        none
