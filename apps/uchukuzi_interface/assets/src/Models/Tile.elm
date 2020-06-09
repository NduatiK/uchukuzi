module Models.Tile exposing
    ( Tile
    , tileAt
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


tileAt location =
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
    Location lng lat
