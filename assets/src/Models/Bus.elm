module Models.Bus exposing (Bus, Route)


type alias Bus =
    { id : Int
    , numberPlate : String
    , seats_available : Int
    , vehicleType : String
    , stated_milage : Float
    , route : Maybe Route

    -- , current_location : Maybe Location
    }


type alias Route =
    { id : String
    , name : String
    }
