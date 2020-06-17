port module Ports exposing (..)

{-| -}

import Models.Bus exposing (LocationUpdate)
import Models.Location exposing (Location)
import Models.Route exposing (Route)
import Models.Tile exposing (Tile)



-- OUTGOING


{-| Accepts bool `is clickable` which when true allows creating a circle
-}
port initializeCustomMap : { drawable : Bool, clickable : Bool } -> Cmd msg


initializeMaps : Cmd msg
initializeMaps =
    initializeCustomMap { drawable = False, clickable = False }


port fitBoundsMap : () -> Cmd msg


fitBounds : Cmd msg
fitBounds =
    fitBoundsMap ()


port setDeviationTileVisible : Bool -> Cmd msg


port drawDeviationTiles :
    { correct : List Tile
    , deviation : List Tile
    , visible : Bool
    }
    -> Cmd msg


initializeSearch : Cmd msg
initializeSearch =
    initializeSearchPort ()


port initializeSearchPort : () -> Cmd msg


port requestGeoLocation : () -> Cmd msg


port initializeCamera : () -> Cmd msg


port disableCamera : Int -> Cmd msg


port setFrameFrozen : Bool -> Cmd msg


port selectPoint : { location : { lat : Float, lng : Float }, bearing : Float } -> Cmd msg


port deselectPoint : () -> Cmd msg


port updateBusMap : LocationUpdate -> Cmd msg


port bulkUpdateBusMap : List LocationUpdate -> Cmd msg


printCard : Cmd msg
printCard =
    printCardPort ()


port printCardPort : () -> Cmd msg


drawEditableRoute : Route -> Cmd msg
drawEditableRoute route =
    drawEditablePath { routeID = route.id, path = route.path, highlighted = False, editable = True }


drawRoute : Route -> Cmd msg
drawRoute route =
    drawPath { routeID = route.id, path = route.path, highlighted = False }


port drawEditablePath : { routeID : Int, path : List Location, highlighted : Bool, editable : Bool } -> Cmd msg


port drawPath : { routeID : Int, path : List Location, highlighted : Bool } -> Cmd msg


port bulkDrawPath :
    List
        { routeID : Int
        , path : List Location
        , highlighted : Bool
        }
    -> Cmd msg


port showHomeLocation : Location -> Cmd msg


port highlightPath : { routeID : Int, highlighted : Bool } -> Cmd msg


port cleanMap : () -> Cmd msg


port disableClickListeners : () -> Cmd msg


port insertCircle : { location : Location, radius : Float } -> Cmd msg


port renderChart :
    { x : List Int
    , y :
        { consumptionOnDate : List Float
        , runningAverage : List Float
        }
    , statistics :
        Maybe
            { stdDev : Float
            , mean : Float
            }
    }
    -> Cmd msg



-- INCOMING


port receiveCameraActive : (Bool -> msg) -> Sub msg


port scannedDeviceCode : (String -> msg) -> Sub msg


port noCameraFoundError : (Bool -> msg) -> Sub msg


port receivedMapClickLocation : (Maybe { lat : Float, lng : Float, radius : Float } -> msg) -> Sub msg


port receivedMapLocation : (Location -> msg) -> Sub msg


port onBusMove : (LocationUpdate -> msg) -> Sub msg


port autocompleteError : (Bool -> msg) -> Sub msg


port updatedPath : (List Location -> msg) -> Sub msg
