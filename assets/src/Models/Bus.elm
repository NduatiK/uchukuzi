module Models.Bus exposing (Bus)


type alias Bus =
    { id : Int
    , numberPlate : String
    , seats_available : Int
    , vehicleType : String
    , stated_milage : Float

    -- , current_location : Maybe Location
    }
