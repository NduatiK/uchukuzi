module StyledElement exposing
    ( Errors(..)
    , InputError(..)
    , button
    , buttonLink
    , checkboxIcon
    , dropDown
    , emailInput
    , iconButton
    , inputErrorsFor
    , navigationLink
    , numberInput
    , passwordInput
    , textInput
    , textLink
    , toClientSideError
    , toClientSideErrors
    , toDropDownView
    , toServerSideErrors
    , wrappedInput
    )

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Icons exposing (IconBuilder)
import Regex
import Route
import Style exposing (..)
import Views.CustomDropDown as Dropdown


type InputError
    = InputError (List String)


type alias FieldName =
    String


type Errors internalError
    = ClientSideError internalError String
    | ServerSideError FieldName (List String)


inputErrorsFor : List (Errors clientError) -> String -> List clientError -> Maybe InputError
inputErrorsFor formProblems fieldName errorsToMatch =
    let
        clientSideErrors =
            List.map (\x -> ClientSideError x "") errorsToMatch
    in
    Maybe.map InputError
        (errorWhenContains
            clientSideErrors
            formProblems
            fieldName
        )


toClientSideError : ( a, String ) -> Errors a
toClientSideError problem =
    ClientSideError (Tuple.first problem) (Tuple.second problem)


toClientSideErrors : List ( a, String ) -> List (Errors a)
toClientSideErrors problems =
    List.map (\x -> ClientSideError (Tuple.first x) (Tuple.second x)) problems


toServerSideErrors : List ( String, List String ) -> List (Errors a)
toServerSideErrors formErrors =
    List.map (\x -> ServerSideError (Tuple.first x) (Tuple.second x)) formErrors



-- errorWhenContains : List (Errors e) -> List (Errors e) -> (e -> String) -> String -> Maybe (List String)
-- errorWhenContains possibleFieldProblems formProblems clientSideToString fieldName =


errorWhenContains : List (Errors e) -> List (Errors e) -> String -> Maybe (List String)
errorWhenContains matchFields formProblems fieldName =
    let
        containsError a list =
            List.any
                (\x ->
                    case ( a, x ) of
                        ( ServerSideError aFieldName _, ServerSideError xFieldName _ ) ->
                            aFieldName == xFieldName

                        ( ClientSideError aError _, ClientSideError xError _ ) ->
                            aError == xError

                        _ ->
                            False
                )
                list

        errorsForField =
            List.filter (\x -> containsError x matchFields) formProblems

        beautifyError =
            \x ->
                case x of
                    ClientSideError _ string ->
                        [ string ]

                    ServerSideError fieldName2 strings ->
                        List.map (\str -> "This " ++ String.replace "_" " " fieldName2 ++ " " ++ str) strings
    in
    case List.concatMap beautifyError errorsForField of
        [] ->
            Nothing

        errorStrings ->
            Just errorStrings


navigationLink : List (Attribute msg) -> { label : Element msg, route : Route.Route } -> Element msg
navigationLink attrs config =
    Element.link
        (textFontStyle
            ++ [ paddingXY 27 10
               , Font.size 19
               , Font.color Style.purpleColor
               , Element.mouseOver
                    [ alpha 0.9
                    ]

               --    , Font.medium
               ]
            ++ labelFontStyle
            ++ attrs
        )
        { url = Route.href config.route
        , label = config.label
        }


buttonLink : { label : Element msg, route : Route.Route } -> Element msg
buttonLink config =
    Element.link
        (textFontStyle
            ++ [ Background.color purpleColor

               --    , paddingXY 38 10
               --    , Font.color (Element.rgb 1 1 1)
               --    , Font.size 18
               --    , Border.rounded 3
               , Element.mouseOver
                    [ alpha 0.9 ]
               ]
        )
        { url = Route.href config.route
        , label = config.label
        }


textLink : List (Attribute msg) -> { label : Element msg, route : Route.Route } -> Element msg
textLink attributes config =
    link
        (textFontStyle
            ++ [ Font.color purpleColor
               , Font.size 18
               , Border.rounded 3
               , Element.mouseOver
                    [ alpha 0.9 ]
               ]
            ++ attributes
        )
        { url = Route.href config.route
        , label = config.label
        }


button :
    List (Attribute msg)
    -> { label : Element msg, onPress : Maybe msg }
    -> Element msg
button attributes config =
    Input.button
        ([ Background.color purpleColor
         , paddingXY 38 10
         , Font.color (Element.rgb 1 1 1)
         , Font.size 18
         , Border.rounded 3
         , height (px 46)
         , Style.animatesAll
         , Style.cssResponsive
         , Element.mouseOver
            [ moveUp 1
            , Border.shadow { offset = ( 0, 4 ), size = 0, blur = 8, color = rgba 0 0 0 0.14 }
            ]
         ]
            ++ Style.textFontStyle
            ++ attributes
        )
        { onPress = config.onPress
        , label = config.label
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
         , Background.color Style.purpleColor
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
        }
    -> ( Element msg, Dropdown.Config item msg, List item )
dropDown attributes { title, caption, dropdownState, dropDownMsg, onSelect, errorCaption, options, ariaLabel, icon, toString } =
    let
        config : Dropdown.Config item msg
        config =
            Dropdown.dropDownConfig dropDownMsg onSelect toString icon

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
        [ Border.color Style.errorColor, Border.solid, Border.width 2 ]


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
                -- Just (InputError captionText) ->
                --     Element.paragraph (Style.labelStyle ++ [ Font.color Style.errorColor ]) [ text captionText ]
                -- Just (ServerError errors) ->
                --     Element.paragraph (Style.labelStyle ++ [ Font.color Style.errorColor ]) (List.map text errors)
                Just (InputError errors) ->
                    Element.paragraph (Style.labelStyle ++ [ Font.color Style.errorColor ]) (List.map text errors)

                -- Just (Ser errors) ->
                --     Element.paragraph (Style.labelStyle ++ [ Font.color Style.errorColor ]) (List.map text errors)
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
                    , onPress = Just (onChange (value - 1))
                    }
                , el [ Background.color (rgba 0 0 0 0.12), width <| px 1, height <| px 20 ] none
                , Input.button []
                    { label = Icons.add [ width <| px 24, height <| px 24 ]
                    , onPress = Just (onChange (value + 1))
                    }
                , el [ width <| px 0, height <| px 20 ] none
                ]
    in
    body
