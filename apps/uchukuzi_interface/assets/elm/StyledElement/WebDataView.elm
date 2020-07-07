module StyledElement.WebDataView exposing (view)

import Api
import Element exposing (Element, centerX, centerY, el, height, paragraph, px, text, width)
import Errors
import Icons
import RemoteData exposing (RemoteData(..), WebData)
import Style



-- SHORTCUTS


view : WebData a -> (a -> Element msg) -> Element msg
view remoteData successView =
    case remoteData of
        Success data ->
            successView data

        Failure error ->
            el [ centerX, centerY ] (text (Errors.errorToString error))

        _ ->
            Icons.loading [ centerX, centerY, width (px 46), height (px 46) ]
