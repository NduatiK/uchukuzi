module Pages.LoadingPage exposing (..)

import Browser
import Element exposing (..)
import Html
import Html.Attributes exposing (id)
import Icons
import Style


view : Element msg
view =
    let
        renderedView =
            el [ htmlAttribute (id "elm"), height fill, width fill ]
                (Icons.loading [ centerX, centerY ])
    in
    renderedView
