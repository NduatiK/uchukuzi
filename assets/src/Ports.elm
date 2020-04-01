port module Ports exposing (deselectPoint, disableCamera, initializeCamera, initializeMaps, noCameraFoundError, receiveCameraActive, receivedMapClickLocation, requestGeoLocation, scannedDeviceCode, selectPoint, setFrameFrozen)

-- OUTGOING


port initializeMaps : (Bool) -> Cmd msg


port requestGeoLocation : () -> Cmd msg


port selectPoint : { lat : Float, lng : Float } -> Cmd msg


port deselectPoint : () -> Cmd msg


port initializeCamera : () -> Cmd msg


port disableCamera : Int -> Cmd msg


port setFrameFrozen : Bool -> Cmd msg



-- INCOMING


port receiveCameraActive : (Bool -> msg) -> Sub msg


port scannedDeviceCode : (String -> msg) -> Sub msg


port noCameraFoundError : (Bool -> msg) -> Sub msg


port receivedMapClickLocation : (Maybe { lat : Float, lng : Float, radius : Float } -> msg) -> Sub msg
