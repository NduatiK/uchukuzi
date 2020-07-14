module StyledElement.DatePicker exposing (update, view)

import Date
import DatePicker
import Element exposing (..)
import Element.Border as Border
import Errors exposing (InputError)
import Html
import Html.Events as Events
import Icons exposing (IconBuilder)
import Json.Decode as Decode
import Style
import StyledElement exposing (wrappedInput)
import Utils.DateParser as DateParser


config : DatePicker.Settings
config =
    let
        default =
            DatePicker.defaultSettings
    in
    { default
        | dateFormatter = Date.format "dd-MM-yyyy"
        , placeholder = "Select a date eg 31-12-2020"
        , parser = DateParser.fromDateString
    }


update :
    DatePicker.Msg
    -> DatePicker.DatePicker
    -> ( DatePicker.DatePicker, DatePicker.DateEvent )
update =
    DatePicker.update config


view :
    List (Attribute msg)
    ->
        { title : String
        , caption : Maybe String
        , errorCaption : Maybe (InputError e)
        , icon : Maybe (IconBuilder msg)
        , onChange : DatePicker.Msg -> msg
        , value : Maybe Date.Date
        , state : DatePicker.DatePicker
        , hasInvalidInput : Bool
        }
    -> Element msg
view attributes { title, caption, errorCaption, value, onChange, state, icon, hasInvalidInput } =
    let
        input =
            el
                [ paddingXY 12 0
                , width fill
                , Style.class "focus-within"
                , height fill
                , Border.rounded 5
                ]
                (el [ centerY, width fill, onEnterPressed (DatePicker.close |> onChange) ]
                    (DatePicker.view value config state
                        |> Html.map onChange
                        |> html
                    )
                )

        errorCaptionWithDateValidation =
            let
                dateValidation =
                    if hasInvalidInput then
                        [ Errors.ServerSideError "date" [ "has an invalid date format" ] ]

                    else
                        []
            in
            case ( errorCaption, dateValidation ) of
                ( _, [] ) ->
                    Nothing

                ( Nothing, _ ) ->
                    Just (InputError "date" dateValidation)

                ( Just { errors, visibleName }, _ ) ->
                    Just (InputError visibleName (dateValidation ++ errors))
    in
    wrappedInput input title caption errorCaptionWithDateValidation icon attributes []


onEnterPressed :
    msg
    -> Attribute msg
onEnterPressed msg =
    let
        stringToKey str =
            case str of
                "Enter" ->
                    Decode.succeed msg

                _ ->
                    Decode.fail "not used key"

        keyDecoder =
            Decode.field "key" Decode.string
                |> Decode.andThen stringToKey
    in
    Events.on "keydown" keyDecoder
        |> htmlAttribute
