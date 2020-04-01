module Page exposing (frame, transformToModelMsg)

import Element exposing (..)
import Element.Border as Border
import Route exposing (Route)
import Session
import Template.NavBar as NavBar exposing (viewHeader)
import Template.TabBar as TabBar


{-| Transforms a (foreign model, foreign msg) into a (local model, msg)
-}
transformToModelMsg : (subModel -> model) -> (subMsg -> msg) -> ( subModel, Cmd subMsg ) -> ( model, Cmd msg )
transformToModelMsg toModel toMsg ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )


frame : Maybe Route -> Element a -> Session.Session -> (a -> msg) -> NavBar.Model -> (NavBar.Msg -> msg) -> Int -> Element msg
frame route body session toMsg navState headerToMsg pageHeight =
    let
        bottomBar =
            if Session.getCredentials session == Nothing || Route.isPublicRoute route then
                none

            else
                TabBar.view route

        renderedBody =
            el
                [ width fill
                , height (px (pageHeight - NavBar.maxHeight - TabBar.maxHeight - 5))
                , alignTop
                , scrollbarY
                ]
                (Element.map toMsg body)

        renderedHeader =
            Element.map headerToMsg (viewHeader navState session route)
    in
    column [ width fill, height fill ]
        [ renderedHeader
        , renderedBody
        , bottomBar
        ]
