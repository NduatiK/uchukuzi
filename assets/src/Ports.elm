port module Ports exposing (..)

{-| -}

import Models.Bus exposing (LocationUpdate)



-- OUTGOING


{-| Accepts bool `is clickable` which when true allows creating a circle
-}
port initializeLiveView : () -> Cmd msg


port initializeMaps : Bool -> Cmd msg


port requestGeoLocation : () -> Cmd msg


port selectPoint : { lat : Float, lng : Float } -> Cmd msg


port deselectPoint : () -> Cmd msg


port initializeCamera : () -> Cmd msg


port disableCamera : Int -> Cmd msg


port setFrameFrozen : Bool -> Cmd msg


port updateBusMap : LocationUpdate -> Cmd msg


port bulkUpdateBusMap : List LocationUpdate -> Cmd msg



-- INCOMING


port receiveCameraActive : (Bool -> msg) -> Sub msg


port scannedDeviceCode : (String -> msg) -> Sub msg


port noCameraFoundError : (Bool -> msg) -> Sub msg


port receivedMapClickLocation : (Maybe { lat : Float, lng : Float, radius : Float } -> msg) -> Sub msg


port onBusMove : (LocationUpdate -> msg) -> Sub msg


port mapReady : (Bool -> msg) -> Sub msg
