module Models.Tile exposing
    ( Tile
    , contains
    , newTile
    )

import Models.Location exposing (Location)


type alias Tile =
    { bottomLeft : Location
    , topRight : Location
    }



-- tileAt location =
--     let
--         coord =
--             originOfTile location
--     in
--     Tile coord (offset coord)


newTile location =
    Tile location (offset location)



-- see apps/uchukuzi/lib/uchukuzi/world/tile.ex


size =
    0.0025


originOfTile location =
    Location (toFloat (floor (location.lng / size)) * size)
        (toFloat (floor (location.lat / size)) * size)


offset origin =
    let
        lat =
            if origin.lat + size > 90 then
                90

            else
                origin.lat + size

        lng =
            if origin.lng + size > 180 then
                180

            else
                origin.lng + size
    in
    Location (round10000 lng) (round10000 lat)


contains : Location -> Tile -> Bool
contains location tile =
    ((tile.bottomLeft.lng < location.lng) && (location.lng < tile.topRight.lng))
        && ((tile.bottomLeft.lat < location.lat) && (location.lat < tile.topRight.lat))


round10000 : Float -> Float
round10000 float =
    toFloat (round (float * 10000)) / 10000
