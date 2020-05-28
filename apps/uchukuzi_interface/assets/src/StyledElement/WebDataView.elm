module StyledElement.WebDataView exposing (view)

import Element exposing (Element, centerX, centerY, el, height, paragraph, px, text, width)
import Icons
import RemoteData exposing (RemoteData(..), WebData)
import Style



-- SHORTCUTS


view : WebData a -> (a -> Element msg) -> Element msg
view remoteData successView =
    case remoteData of
        Success data ->
            successView data

        Failure _ ->
            el (centerX :: centerY :: Style.labelStyle) (paragraph [] [ text "Something went wrong, please reload the page" ])

        _ ->
            Icons.loading [ centerX, centerY, width (px 46), height (px 46) ]
