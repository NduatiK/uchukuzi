module Pages.Buses.Bus.Navigation exposing (BusPage(..), allBusPages, busPageToString)


type BusPage
    = About
    | TripHistory
    | FuelHistory
    | BusDevice
    | BusRepairs


allBusPages =
    [ About
    , TripHistory
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

                TripHistory ->
                    "Trips"

                FuelHistory ->
                    "Fuel_Log"

                BusDevice ->
                    "Device"

                BusRepairs ->
                    "Maintenance"
    in
    string
