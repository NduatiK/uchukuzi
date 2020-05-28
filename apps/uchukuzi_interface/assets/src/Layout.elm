module Layout exposing (frame, transformToModelMsg, viewHeight)

import Element exposing (..)
import Html.Attributes exposing (id)
import Navigation exposing (Route)
import Session
import Style exposing (edges)
import Template.NavBar as NavBar exposing (viewHeader)
import Template.SideBar as SideBar
import Template.TabBar as TabBar exposing (TabBarItem(..))


{-| Transforms a (foreign model, foreign msg) into a (local model, msg)
-}
transformToModelMsg : (subModel -> model) -> (subMsg -> msg) -> ( subModel, Cmd subMsg ) -> ( model, Cmd msg )
transformToModelMsg toModel toMsg ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )


viewHeight : Int -> Int
viewHeight pageHeight =
    pageHeight - NavBar.maxHeight


frame : Maybe Route -> Element a -> Session.Session -> (a -> msg) -> NavBar.Model -> (NavBar.Msg -> msg) -> SideBar.Model -> (SideBar.Msg -> msg) -> Int -> List (TabBarItem a) -> Element msg
frame route body session toMsg navState headerToMsg sideBarState sideBarToMsg pageHeight tabBarItems =
    let
        sideBar =
            if Session.getCredentials session == Nothing || Navigation.isPublicRoute route then
                none

            else
                Element.map sideBarToMsg (SideBar.view route sideBarState (viewHeight pageHeight))

        bottomBar =
            -- if Session.getCredentials session == Nothing || Navigation.isPublicRoute route || tabBarItems == [] then
            if Session.getCredentials session == Nothing || Navigation.isPublicRoute route then
                none

            else
                TabBar.view tabBarItems toMsg

        renderedBody =
            row [ width fill, spacing -(2 * (SideBar.handleBarSpacing + SideBar.handleBarWidth)) ]
                [ sideBar
                , column
                    [ width fill
                    , paddingEach { edges | left = SideBar.handleBarSpacing + SideBar.handleBarWidth }
                    , height (px (viewHeight pageHeight))
                    , alignTop

                    -- , route
                    --     |> Maybe.andThen (Navigation.href >> Just)
                    --     |> Maybe.withDefault ""
                    --     |> id
                    --     |> htmlAttribute
                    ]
                    [ Element.map toMsg (el [ paddingEach { edges | left = 20 }, width fill, height fill ] body)
                    , bottomBar
                    ]
                ]

        renderedHeader =
            Element.map headerToMsg (viewHeader navState session route)
    in
    column [ width fill, height fill ]
        [ renderedHeader
        , renderedBody
        ]



-- viewHeight : Int -> Int
-- viewHeight pageHeight =
--     pageHeight - NavBar.maxHeight - TabBar.maxHeight
-- frame : Maybe Route -> Element a -> Session.Session -> (a -> msg) -> NavBar.Model -> (NavBar.Msg -> msg) -> Int -> Element msg
-- frame route body session toMsg navState headerToMsg pageHeight =
--     let
--         bottomBar =
--             if Session.getCredentials session == Nothing || Navigation.isPublicRoute route then
--                 none
--             else
--                 TabBar.view route
--         renderedBody =
--             el
--                 [ width fill
--                 , height (px (viewHeight pageHeight))
--                 , alignTop
--                 , scrollbarY
--                 ]
--                 (Element.map toMsg body)
--         renderedHeader =
--             Element.map headerToMsg (viewHeader navState session route)
--     in
--     column [ width fill, height fill ]
--         [ renderedHeader
--         , renderedBody
--         , bottomBar
--         ]
