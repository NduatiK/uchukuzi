module Pages.Settings exposing (Model, Msg, init, tabBarItems, update, view)

import Api
import Element exposing (..)
import Html exposing (Html)
import Html.Events exposing (..)
import Icons
import Session exposing (Session)
import Style exposing (edges)
import Template.TabBar as TabBar exposing (TabBarItem(..))


type alias Model =
    { session : Session }


init : Session -> ( Model, Cmd msg )
init session =
    ( Model session
    , Cmd.none
    )



-- UPDATE


type Msg
    = Logout


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Logout ->
            ( model
            , Cmd.batch
                [ -- sendLogout
                  Api.logout
                ]
            )



-- VIEW


view : Model -> Element Msg
view model =
    Element.column
        [ width fill, spacing 40, padding 30, height fill ]
        [ Style.iconHeader Icons.settings "Settings"

        -- , el [] (text "Welcome")
        ]


tabBarItems model =
    [ TabBar.Button
        { title = "Logout"
        , icon = Icons.exit
        , onPress = Logout
        }
    ]
