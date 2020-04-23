port module Ports exposing (..)

{-| -}

import Models.Bus exposing (LocationUpdate)
import Models.Location exposing (Location)



-- OUTGOING


{-| Accepts bool `is clickable` which when true allows creating a circle
-}
port initializeLiveView : () -> Cmd msg


port initializeCustomMap : { drawable : Bool, clickable : Bool } -> Cmd msg


initializeMaps : Cmd msg
initializeMaps =
    initializeCustomMap { drawable = False, clickable = False }


initializeSearch : Cmd msg
initializeSearch =
    initializeSearchPort ()


port initializeSearchPort : () -> Cmd msg


port requestGeoLocation : () -> Cmd msg


port selectPoint : { lat : Float, lng : Float } -> Cmd msg


port deselectPoint : () -> Cmd msg


port initializeCamera : () -> Cmd msg


port disableCamera : Int -> Cmd msg


port setFrameFrozen : Bool -> Cmd msg


port updateBusMap : LocationUpdate -> Cmd msg


port bulkUpdateBusMap : List LocationUpdate -> Cmd msg


printCard : Cmd msg
printCard =
    printCardPort ()


port printCardPort : () -> Cmd msg


port drawPath : { routeID : Int, path : List Location } -> Cmd msg


port bulkDrawPath : List { routeID : Int, path : List Location } -> Cmd msg


port highlightPath : { routeID : Int, highlighted : Bool } -> Cmd msg



-- INCOMING


port receiveCameraActive : (Bool -> msg) -> Sub msg


port scannedDeviceCode : (String -> msg) -> Sub msg


port noCameraFoundError : (Bool -> msg) -> Sub msg


port receivedMapClickLocation : (Maybe { lat : Float, lng : Float, radius : Float } -> msg) -> Sub msg


port receivedMapLocation : (Location -> msg) -> Sub msg


port onBusMove : (LocationUpdate -> msg) -> Sub msg


port mapReady : (Bool -> msg) -> Sub msg


port autocompleteError : (Bool -> msg) -> Sub msg


port updatedPath : (List Location -> msg) -> Sub msg
