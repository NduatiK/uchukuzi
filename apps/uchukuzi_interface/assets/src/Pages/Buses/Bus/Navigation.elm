module Pages.Buses.Bus.Navigation exposing (BusPage(..), allBusPages, busPageToString)


type BusPage
    = About
    | RouteHistory
    | FuelHistory
    | BusDevice
    | BusRepairs


allBusPages =
    [ About
    , RouteHistory
    , FuelHistory
    , BusDevice
    , BusRepairs
    ]


busPageToString : BusPage -> String
busPageToString page =
    let
        string =
            case page of
                About ->
                    "Summary"

                RouteHistory ->
                    "Trips"

                FuelHistory ->
                    "Fuel_Log"

                BusDevice ->
                    "Device"

                BusRepairs ->
                    "Maintenance"
    in
    String.replace " " "_" string
