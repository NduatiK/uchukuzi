module Layout exposing
    ( frame
    , sideBarOffset
    , transformToModelMsg
    , viewHeight
    )

import Element exposing (..)
import Html.Attributes exposing (id)
import Icons
import Layout.NavBar as NavBar
import Layout.SideBar as SideBar
import Layout.TabBar as TabBar exposing (TabBarItem(..))
import Models.Notification exposing (Notification)
import Navigation exposing (Route)
import Session
import Style


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


sideBarOffset : Int
sideBarOffset =
    SideBar.handleBarSpacing + SideBar.handleBarWidth


frame :
    Session.Session
    -> Maybe Route
    -> { body : Element a, bodyMsgToPageMsg : a -> msg }
    -> { navBarState : NavBar.Model, notifications : List Notification, navBarMsgToPageMsg : NavBar.Msg -> msg }
    -> { sideBarState : SideBar.Model, sideBarMsgToPageMsg : SideBar.Msg -> msg }
    -> Int
    -> List (TabBarItem a)
    -> Element msg
frame session route { body, bodyMsgToPageMsg } { navBarState, notifications, navBarMsgToPageMsg } { sideBarState, sideBarMsgToPageMsg } pageHeight tabBarItems =
    let
        sideBar =
            if Session.getCredentials session == Nothing || Navigation.isPublicRoute route then
                none

            else
                Element.map sideBarMsgToPageMsg (SideBar.view route sideBarState (viewHeight pageHeight))

        bottomBar =
            if Session.getCredentials session == Nothing || Navigation.isPublicRoute route || tabBarItems == [] then
                -- if Session.getCredentials session == Nothing || Navigation.isPublicRoute route then
                none

            else
                TabBar.view tabBarItems bodyMsgToPageMsg

        bodyContent =
            Element.map bodyMsgToPageMsg
                (el [ width fill, height fill ] body)

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
                , column [ width fill, height (px (viewHeight pageHeight)), alignTop ]
                    [ bodyContent
                    , bottomBar
                    ]
                ]

        renderedHeader =
            Element.map navBarMsgToPageMsg (NavBar.view navBarState session route notifications)
    in
    column [ width fill, height fill ]
        [ renderedHeader
        , renderedBody
        ]
