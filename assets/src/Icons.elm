module Icons exposing (..)

import Colors
import Element exposing (Attribute, Element, alpha, height, image, px, width)
import Style


type alias IconBuilder msg =
    List (Attribute msg) -> Element msg


bus : List (Attribute msg) -> Element msg
bus attrs =
    image
        -- ([ width <| px 437, height <| px 137 ]
        ([ width <| px 218, height <| px 68 ]
            ++ attrs
        )
        { src = "images/busOutlines/bus.svg", description = "" }


van : List (Attribute msg) -> Element msg
van attrs =
    image
        -- ([ width <| px 246, height <| px 113 ]
        ([ width <| px 123, height <| px 56 ]
            ++ attrs
        )
        { src = "images/busOutlines/van.svg", description = "" }


shuttle : List (Attribute msg) -> Element msg
shuttle attrs =
    image
        -- ([ width <| px 332, height <| px 126 ]
        ([ width <| px 176, height <| px 73 ]
            ++ attrs
        )
        { src = "images/busOutlines/shuttle.svg", description = "" }


qrBox : List (Attribute msg) -> Element msg
qrBox attrs =
    image
        ([ width <| px 506, height <| px 286 ]
            ++ attrs
        )
        { src = "images/qrBox.svg", description = "" }


add : List (Attribute msg) -> Element msg
add attrs =
    image attrs
        { src = "images/add.svg", description = "" }


edit : List (Attribute msg) -> Element msg
edit attrs =
    image attrs
        { src = "images/edit.svg", description = "" }


subtract : List (Attribute msg) -> Element msg
subtract attrs =
    image attrs
        { src = "images/subtract.svg", description = "" }


steeringWheel : List (Attribute msg) -> Element msg
steeringWheel attrs =
    image attrs
        { src = "images/stearing_wheel.svg", description = "" }


addWhite : List (Attribute msg) -> Element msg
addWhite attrs =
    add (attrs ++ [ Colors.fillWhite ])


camera : List (Attribute msg) -> Element msg
camera attrs =
    image attrs
        { src = "images/camera.svg", description = "" }


cameraOff : List (Attribute msg) -> Element msg
cameraOff attrs =
    image attrs
        { src = "images/camera_off.svg", description = "" }


chevronDown : List (Attribute msg) -> Element msg
chevronDown attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/chevron_down.svg", description = "" }


dashboard : List (Attribute msg) -> Element msg
dashboard attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/dashboard.svg", description = "" }


filter : List (Attribute msg) -> Element msg
filter attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/filter.svg", description = "" }


pin : List (Attribute msg) -> Element msg
pin attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/pin.svg", description = "" }


seat : List (Attribute msg) -> Element msg
seat attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/seat.svg", description = "" }


people : List (Attribute msg) -> Element msg
people attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/people.svg", description = "" }


phone : List (Attribute msg) -> Element msg
phone attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/phone.svg", description = "" }


email : List (Attribute msg) -> Element msg
email attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/email.svg", description = "" }


trash : List (Attribute msg) -> Element msg
trash attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/trash.svg", description = "" }


info : List (Attribute msg) -> Element msg
info attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/info.svg", description = "" }


help : List (Attribute msg) -> Element msg
help attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/help.svg", description = "" }


loading : List (Attribute msg) -> Element msg
loading attrs =
    image
        (width (px 48)
            :: height (px 48)
            -- :: alpha 0.54
            :: attrs
        )
        { src = "images/loading.svg", description = "" }


timeline : List (Attribute msg) -> Element msg
timeline attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/timeline.svg", description = "" }


repairs : List (Attribute msg) -> Element msg
repairs attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/repairs.svg", description = "" }


hardware : List (Attribute msg) -> Element msg
hardware attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/hardware.svg", description = "" }


search : List (Attribute msg) -> Element msg
search attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/search.svg", description = "" }


check : List (Attribute msg) -> Element msg
check attrs =
    image attrs
        { src = "images/check.svg", description = "" }


vehicle : List (Attribute msg) -> Element msg
vehicle attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/shuttle.svg", description = "" }


fuel : List (Attribute msg) -> Element msg
fuel attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/fuel.svg", description = "" }


emptySeat : List (Attribute msg) -> Element msg
emptySeat attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/seat-empty.svg", description = "" }


occupiedSeat : List (Attribute msg) -> Element msg
occupiedSeat attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/seat-occupied.svg", description = "" }


dashedBox : List (Attribute msg) -> Element msg
dashedBox attrs =
    image (alpha 0.54 :: attrs)
        { src = "images/dotted_box.svg", description = "" }


iconNamed : String -> List (Attribute msg) -> Element msg
iconNamed name attrs =
    image (alpha 0.54 :: attrs)
        { src = name, description = "" }


close : List (Attribute msg) -> Element msg
close =
    iconNamed "images/close.svg"


box : List (Attribute msg) -> Element msg
box =
    iconNamed "images/box.svg"


save : List (Attribute msg) -> Element msg
save =
    iconNamed "images/save.svg"
