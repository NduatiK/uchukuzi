module StyledElement.DatePicker exposing (update, view)

import Date
import DatePicker
import Element exposing (..)
import Errors exposing (InputError)
import Html
import Html.Attributes
import Icons exposing (IconBuilder)
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
        }
    -> Element msg
view attributes { title, caption, errorCaption, value, onChange, state, icon } =
    let
        input =
            el [ paddingXY 12 0, width fill, htmlAttribute (Html.Attributes.class "focus-within") ]
                (html
                    (DatePicker.view value config state
                        |> Html.map onChange
                    )
                )
    in
    wrappedInput input title caption errorCaption icon attributes []
