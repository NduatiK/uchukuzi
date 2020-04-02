module Models.Bus exposing (Bus, Device, Route)


type alias Bus =
    { id : Int
    , numberPlate : String
    , seats_available : Int
    , vehicleType : String
    , stated_milage : Float
    , route : Maybe Route
    , device : Maybe Device

    -- , current_location : Maybe Location
    }


type alias Route =
    { id : String
    , name : String
    }


type alias Device =
    String



-- { id : String
-- , name : String
-- }
