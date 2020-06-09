module Layout exposing
    ( frame
    , sideBarOffset
    , transformToModelMsg
    , viewHeight
    )

import Element exposing (..)
import Html.Attributes exposing (id)
import Icons
import Models.Notification exposing (Notification)
import Navigation exposing (Route)
import Session
import Style exposing (edges)
import Template.NavBar as NavBar
import Template.SideBar as SideBar
import Template.TabBar as TabBar exposing (TabBarItem(..))
import Views.NotificationView as NotificationView


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


sideBarOffset =
    SideBar.handleBarSpacing + SideBar.handleBarWidth


frame :
    Maybe Route
    -> Element a
    -> Session.Session
    -> (a -> msg)
    -> NavBar.Model
    -> List Notification
    -> (NavBar.Msg -> msg)
    -> SideBar.Model
    -> (SideBar.Msg -> msg)
    -> Int
    -> List (TabBarItem a)
    -> Element msg
frame route body session toMsg navState notifications headerToMsg sideBarState sideBarToMsg pageHeight tabBarItems =
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
            row
                [ width fill
                , spacing -sideBarOffset
                , inFront
                    (row [ Style.clickThrough, alpha 0 ]
                        [ Icons.loading []
                        , Icons.refresh []
                        , Icons.close []
                        ]
                    )
                ]
                [ sideBar
                , column
                    [ width fill
                    , height (px (viewHeight pageHeight))
                    , alignTop
                    ]
                    [ Element.map toMsg
                        (el [ width fill, height fill ] body)
                    , bottomBar
                    ]
                ]

        renderedHeader =
            Element.map headerToMsg (NavBar.view navState session route notifications)
    in
    column [ width fill, height fill ]
        [ renderedHeader
        , renderedBody
        ]
