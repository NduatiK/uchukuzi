module Views.DragAndDrop exposing (draggable, droppable)

import Element exposing (htmlAttribute)
import Html.Attributes exposing (attribute)
import Html.Events exposing (custom, on)
import Json.Decode as Json


{-| Add this to things that can be dragged

    draggable
        { onDragStart = ...
        , onDragEnd = ...
        }

-}
draggable : { onDragStart : msg, onDragEnd : msg } -> List (Element.Attribute msg)
draggable { onDragStart, onDragEnd } =
    [ htmlAttribute (attribute "draggable" "true")
    , htmlAttribute (on "dragstart" <| Json.succeed <| onDragStart)
    , htmlAttribute (on "dragend" <| Json.succeed <| onDragEnd)
    ]


{-| Add this to things that can have things dropped on them

    droppable
        { onDrop = DroppedCrewMemberOntoUnassigned
        , onDragOver = DraggedCrewMemberAboveUnassigned
        }

-}
droppable : { onDrop : msg, onDragOver : msg } -> List (Element.Attribute msg)
droppable { onDrop, onDragOver } =
    [ htmlAttribute (attribute "droppable" "true")
    , htmlAttribute (custom "drop" <| Json.succeed { message = onDrop, preventDefault = True, stopPropagation = True })
    , htmlAttribute (custom "dragover" <| Json.succeed { message = onDragOver, preventDefault = True, stopPropagation = True })
    ]
