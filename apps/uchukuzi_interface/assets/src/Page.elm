module Page exposing (frame, transformToModelMsg, viewHeight)

import Element exposing (..)
import Navigation exposing (Route)
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


viewHeight : Int -> Int
viewHeight pageHeight =
    pageHeight - NavBar.maxHeight - TabBar.maxHeight


frame : Maybe Route -> Element a -> Session.Session -> (a -> msg) -> NavBar.Model -> (NavBar.Msg -> msg) -> Int -> Element msg
frame route body session toMsg navState headerToMsg pageHeight =
    let
        bottomBar =
            if Session.getCredentials session == Nothing || Navigation.isPublicRoute route then
                none

            else
                TabBar.view route

        renderedBody =
            el
                [ width fill
                , height (px (viewHeight pageHeight))
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