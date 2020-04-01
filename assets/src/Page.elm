module Page exposing (frame, transformToModelMsg)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Lazy exposing (lazy)
import Element.Region as Region
import Icons
import Route exposing (Route)
import Session
import Style exposing (edges)
import Template.NavBar as NavBar exposing (viewHeader)
import Template.SideBar exposing (viewSidebar)


{-| Transforms a (foreign model, foreign msg) into a (local model, msg)
-}
transformToModelMsg : (subModel -> model) -> (subMsg -> msg) -> ( subModel, Cmd subMsg ) -> ( model, Cmd msg )
transformToModelMsg toModel toMsg ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )



-- frame : Maybe Route -> Element msg -> Session.Session -> Element msg


frame route body session toMsg navState headerToMsg =
    let
        sidebarParts =
            if Session.getCredentials session == Nothing || Route.isPublicRoute route then
                []

            else
                [ viewSidebar route, viewSidebarDivider ]

        renderedView =
            row [ width fill, height fill, spacingXY 5 0 ]
                (sidebarParts
                    ++ [ el
                            [ width fill
                            , alignTop
                            , height fill
                            ]
                            body
                       ]
                )
    in
    column [ width fill, height fill ]
        [ Element.map headerToMsg (viewHeader navState session route)
        , Element.map toMsg renderedView
        ]


viewSidebarDivider : Element msg
viewSidebarDivider =
    el
        [ height fill
        , paddingEach { edges | top = 10, bottom = 10 }
        ]
        (el
            [ height fill
            , Border.width 1
            , Border.color (rgb255 243 243 243)
            ]
            none
        )
