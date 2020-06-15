module StyledElement.TripSlider exposing (view, viewHeight)

import Axis
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html.Attributes exposing (id)
import Icons exposing (IconBuilder)
import Models.Location exposing (Report)
import Models.Trip as Trip exposing (Trip)
import Path exposing (Path)
import Scale exposing (ContinuousScale)
import Shape
import Style exposing (edges)
import StyledElement exposing (wrappedInput)
import Time
import TypedSvg exposing (circle, defs, g, linearGradient, pattern, polygon, radialGradient, rect, stop, svg)
import TypedSvg.Attributes exposing (class, cx, cy, fontFamily, fx, fy, offset, patternUnits, points, r, stopColor, stopOpacity, stroke, transform, viewBox, x1, x2, y1, y2)
import TypedSvg.Attributes.InPx as InPx exposing (strokeWidth, x, y)
import TypedSvg.Core exposing (Svg)
import TypedSvg.Types exposing (Align(..), AlignmentBaseline(..), AnchorAlignment(..), CoordinateSystem(..), Length(..), Opacity(..), Paint(..), Transform(..))
import Utils.DateFormatter exposing (timeFormatter)


viewHeight : Int
viewHeight =
    93


view :
    { sliderValue : Int
    , zone : Time.Zone
    , trip : Trip
    , onAdjustValue : Int -> msg
    , viewWidth : Int
    , showSpeed : Bool
    }
    -> Element msg
view { sliderValue, zone, trip, onAdjustValue, viewWidth, showSpeed } =
    let
        annotatedReports =
            -- Debug.log "annotatedReports"
            Trip.annotatedReports trip

        max : Int
        max =
            List.length annotatedReports - 1

        currentPointTimeElement : Element msg
        currentPointTimeElement =
            let
                routeStyle =
                    Style.defaultFontFace
                        ++ [ Font.color Colors.darkness
                           , Font.size 14
                           , Font.bold
                           ]
            in
            case Trip.pointAt sliderValue trip of
                Nothing ->
                    case Trip.pointAt (List.length trip.reports - 1) trip of
                        Nothing ->
                            none

                        Just point ->
                            el (centerX :: routeStyle) (text (String.toUpper (Utils.DateFormatter.timeFormatter zone point.time)))

                Just point ->
                    el (centerX :: routeStyle) (text (String.toUpper (Utils.DateFormatter.timeFormatter zone point.time)))

        ticks : Element msg
        ticks =
            let
                createTick annotatedReport =
                    el
                        [ centerY
                        , if annotatedReport.deviated then
                            Background.color Colors.errorRed

                          else
                            Background.color Colors.white
                        , width (px 2)
                        , Border.rounded 1
                        , height (px 8)
                        ]
                        none
            in
            row [ spaceEvenly, width fill, centerY ] (List.map createTick annotatedReports)
    in
    row
        [ paddingXY 10 0
        , Border.color Colors.darkness
        , Border.widthEach { edges | top = 1 }
        , alignBottom
        , height (px viewHeight)
        , Background.color Colors.white
        , width fill

        -- Speed
        , Element.behindContent
            (viewSpeedGraph trip (toFloat viewWidth) showSpeed)
        ]
        [ el [ width (fillPortion 1), width (fillPortion 1) ] none
        , column [ width (fillPortion 40) ]
            [ Input.slider
                [ height (px 48)
                , Element.below (el (Style.captionStyle ++ [ alignLeft ]) (text (String.toUpper (Utils.DateFormatter.timeFormatter zone trip.startTime))))
                , Element.below (el (Style.captionStyle ++ [ alignRight ]) (text (String.toUpper (Utils.DateFormatter.timeFormatter zone trip.endTime))))

                -- Track styling
                , Element.behindContent
                    (row [ height fill, width fill, centerY, Element.behindContent ticks ]
                        [ Element.el
                            -- Filled track
                            [ width (fillPortion sliderValue)
                            , height (px 3)
                            , Background.color Colors.purple
                            , Border.rounded 2
                            ]
                            Element.none
                        , Element.el
                            -- Default track
                            [ width (fillPortion (max - sliderValue))
                            , height (px 3)
                            , alpha 0.38
                            , Background.color Colors.purple
                            , Border.rounded 2
                            ]
                            Element.none
                        ]
                    )
                ]
                { onChange = round >> onAdjustValue
                , label =
                    Input.labelHidden "Timeline Slider"
                , min = 0
                , max = Basics.toFloat max
                , step = Just 1
                , value = Basics.toFloat sliderValue
                , thumb =
                    Input.thumb
                        [ Background.color Colors.purple
                        , width (px 16)
                        , height (px 16)
                        , Border.rounded 8
                        , Border.solid
                        , Border.color (rgb 1 1 1)
                        , Border.width 2
                        , moveRight (-8 + 16 * (toFloat sliderValue / toFloat max))
                        ]
                }
            , currentPointTimeElement
            ]
        , el [ width (fillPortion 1) ] none
        ]


viewSpeedGraph trip viewWidth visible =
    row
        [ width fill
        , height fill
        , paddingXY 10 5
        , if visible then
            alpha 1

          else
            alpha 0.2
        , Style.animatesAll
        ]
        [ el [ width (fillPortion 1), width (fillPortion 1) ] none
        , el [ width (fillPortion 40), height fill ] (viewGraph trip.reports viewWidth)
        , el [ width (fillPortion 1), width (fillPortion 1) ] none
        ]


{-| Adapted from <https://elm-visualization.netlify.app/linechart/>
-}
xScaleBuilder : Int -> Float -> ContinuousScale Float
xScaleBuilder max w =
    Scale.linear ( w, 0 ) ( toFloat max, 0 )


yScaleBuilder : Float -> Float -> ContinuousScale Float
yScaleBuilder max h =
    Scale.linear ( h, 0 ) ( max * 1.5, 0 )


xAxis : ContinuousScale Float -> Svg msg
xAxis xScale =
    Axis.bottom [] xScale


yAxis : ContinuousScale Float -> Svg msg
yAxis yScale =
    Axis.left [ Axis.tickCount 5 ] yScale


transformToLineData : ContinuousScale Float -> ContinuousScale Float -> ( Float, Float ) -> Maybe ( Float, Float )
transformToLineData xScale yScale ( x, y ) =
    Just ( Scale.convert xScale x, Scale.convert yScale y )


line : List ( Float, Float ) -> ContinuousScale Float -> ContinuousScale Float -> Path
line data xScale yScale =
    List.map (transformToLineData xScale yScale) data
        |> Shape.line Shape.monotoneInXCurve


viewGraph : List Report -> Float -> Element msg
viewGraph reports viewWidth =
    let
        speeds =
            reports
                |> List.map .speed

        graphValues =
            if List.length speeds > 0 then
                ( 0, maxSpeed )
                    :: (speeds
                            |> List.indexedMap Tuple.pair
                            |> List.map (Tuple.mapFirst toFloat)
                            |> List.map (Tuple.mapSecond (\x -> maxSpeed - x))
                       )
                    ++ [ ( toFloat (List.length speeds), maxSpeed )
                       , ( toFloat (List.length speeds - 1), maxSpeed )
                       ]

            else
                []

        maxSpeed =
            Maybe.withDefault 3 (List.maximum speeds)

        svgHeight =
            toFloat (viewHeight - 10) / 2

        svgWidth =
            viewWidth - 200

        ( xScale, yScale ) =
            ( xScaleBuilder (List.length reports - 1) svgWidth
            , yScaleBuilder maxSpeed svgHeight
            )
    in
    el [ width fill, height fill ]
        (html
            (svg
                [ viewBox 0 0 svgWidth svgHeight
                ]
                [ defs [] [ gradient ]
                , g
                    [ class [ "series" ]
                    ]
                    [ Path.element (line graphValues xScale yScale)
                        [ stroke <|
                            Paint <|
                                Colors.toSVGColor Colors.darkGreen
                        , strokeWidth 2
                        , TypedSvg.Attributes.fill <| Reference "linGradientDuoVert"

                        -- , TypedSvg.Attributes.fill
                        --     (Paint <|
                        --         Colors.toSVGColor Colors.purple
                        --     )
                        ]
                    ]

                -- ]
                ]
            )
        )


gradient =
    TypedSvg.linearGradient
        [ id "linGradientDuoVert"
        , x1 <| Percent 0.0
        , y1 <| Percent 0.0
        , x2 <| Percent 0.0
        , y2 <| Percent 100.0
        ]
        [ stop [ offset "0%", stopColor "#61A591", stopOpacity <| Opacity 1.0 ] []
        , stop [ offset "100%", stopColor "#ffffff", stopOpacity <| Opacity 1.0 ] []
        ]


round100 : Float -> Float
round100 float =
    toFloat (round (float * 100)) / 100
