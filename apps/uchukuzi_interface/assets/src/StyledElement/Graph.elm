module StyledElement.Graph exposing (view)

import Axis
import Browser.Dom as Dom
import Color
import Colors
import Date
import DatePicker
import Element exposing (..)
import Html
import Html.Attributes exposing (id)
import Icons exposing (IconBuilder)
import Path exposing (Path)
import Scale exposing (ContinuousScale)
import Shape
import Style
import StyledElement exposing (wrappedInput)
import Time
import TypedSvg exposing (g, svg)
import TypedSvg.Attributes exposing (class, fontFamily, stroke, transform, viewBox)
import TypedSvg.Attributes.InPx exposing (strokeWidth)
import TypedSvg.Core exposing (Svg)
import TypedSvg.Types exposing (Paint(..), Transform(..))


{-| Adapted from <https://elm-visualization.netlify.app/linechart/>
-}
w : Float
w =
    700


h : Float
h =
    280


padding : Float
padding =
    30


xScaleBuilder : Maybe Int -> Maybe Int -> Time.Zone -> ContinuousScale Time.Posix
xScaleBuilder min max timezone =
    let
        scale =
            case ( min, max ) of
                ( Just min_, Just max_ ) ->
                    if min_ == max_ then
                        Scale.time timezone ( 0, w - 2 * padding ) ( Time.millisToPosix min_, Time.millisToPosix max_ )

                    else
                        let
                            oneDay =
                                1000 * 3600 * 24
                        in
                        Scale.time timezone ( 0, w - 2 * padding ) ( Time.millisToPosix min_, Time.millisToPosix (max_ + oneDay) )

                _ ->
                    Scale.time timezone ( 0, w - 2 * padding ) ( Time.millisToPosix 0, Time.millisToPosix 1000 )
    in
    scale


yScaleBuilder : Float -> ContinuousScale Float
yScaleBuilder max =
    Scale.linear ( h - 2 * padding, 0 ) ( 0, max * 1.5 )


xAxis : List ( Time.Posix, Float ) -> ContinuousScale Time.Posix -> Svg msg
xAxis model xScale =
    Axis.bottom [ Axis.tickCount (List.length model) ] xScale


yAxis : ContinuousScale Float -> Svg msg
yAxis yScale =
    Axis.left [ Axis.tickCount 5 ] yScale


transformToLineData : ContinuousScale Time.Posix -> ContinuousScale Float -> ( Time.Posix, Float ) -> Maybe ( Float, Float )
transformToLineData xScale yScale ( x, y ) =
    Just ( Scale.convert xScale x, Scale.convert yScale y )


line : List ( Time.Posix, Float ) -> ContinuousScale Time.Posix -> ContinuousScale Float -> Path
line model xScale yScale =
    List.map (transformToLineData xScale yScale) model
        |> Shape.line Shape.monotoneInXCurve


view : List ( Time.Posix, Float ) -> Time.Zone -> Element msg
view chartData timezone =
    let
        times =
            List.map (Tuple.first >> Time.posixToMillis) chartData

        ( xScale, yScale ) =
            ( xScaleBuilder (List.minimum times) (List.maximum times) timezone
            , yScaleBuilder (Maybe.withDefault 3 (List.maximum (List.map Tuple.second chartData)))
            )
    in
    -- el [ width fill, height (px (round h)) ]
    el [ width fill, height fill ]
        (html
            (svg
                [ viewBox 0 0 w h
                , fontFamily [ "SF Pro Text", "sans-serif" ]
                ]
                [ g
                    [ transform [ Translate (padding - 1) (h - padding) ]
                    , fontFamily [ "SF Pro Text", "sans-serif" ]
                    ]
                    [ xAxis chartData xScale ]
                , g
                    [ transform [ Translate (padding - 1) padding ]
                    , fontFamily [ "SF Pro Text", "sans-serif" ]
                    ]
                    [ yAxis yScale ]
                , g [ transform [ Translate padding padding ], class [ "series" ] ]
                    [ Path.element (line chartData xScale yScale)
                        [ stroke <|
                            Paint <|
                                Color.rgb255 30 165 145
                        , strokeWidth 2
                        , TypedSvg.Attributes.fill PaintNone
                        ]
                    ]
                ]
            )
        )
