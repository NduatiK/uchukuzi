module Pages.Settings exposing
    ( Model
    , Msg
    , init
    , subscriptions
    , tabBarItems
    , update
    , view
    )

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Errors exposing (Errors)
import Html exposing (Html)
import Html.Events exposing (..)
import Icons
import Json.Decode as Decode exposing (Decoder, string)
import Json.Encode as Encode
import Models.Location exposing (Location)
import Models.School exposing (School)
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import StyledElement.WebDataView as WebDataView
import Template.TabBar as TabBar exposing (TabBarItem(..))


type alias Model =
    { session : Session
    , overlayType : Maybe OverlayType
    , form : Form
    , schoolDetailsRequest : WebData School
    , requests :
        { editPasswordRequest : WebData ()
        , editSchoolRequest : WebData School
        , updateDeviation :
            { request : WebData Int
            , sliderValue : Int
            }
        }
    }


type OverlayType
    = Password
    | School


type alias Form =
    { oldPassword : String
    , newPassword : String
    , radius : Float
    , schoolName : String
    , location : Location
    , problems : List (Errors.Errors Problem)
    }


type Problem
    = EmptyOldPassword
    | EmptyNewPassword
    | EmptySchoolName


type alias UpdatePasswordForm =
    { oldPassword : String
    , newPassword : String
    }


type alias UpdateSchoolForm =
    { radius : Float
    , schoolName : String
    , location : Location
    }


emptyForm =
    { oldPassword = ""
    , newPassword = ""
    , radius = 50
    , schoolName = ""
    , location = Location 0 0
    , problems = []
    }


emptyRequests schoolRequest =
    { editPasswordRequest = NotAsked
    , editSchoolRequest = NotAsked
    , updateDeviation =
        { request = NotAsked
        , sliderValue =
            case schoolRequest of
                Success school ->
                    school.deviationRadius

                _ ->
                    0
        }
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , overlayType = Nothing
      , form = emptyForm
      , schoolDetailsRequest = Loading
      , requests =
            emptyRequests Loading
      }
    , Cmd.batch
        [ fetchSchoolDetails session ]
    )



-- UPDATE


type Msg
    = NoOp
    | Logout
    | SetOverlay (Maybe OverlayType)
    | ReceivedSchoolDetails (WebData School)
      --------
    | SubmitNewPassword
    | ReceivedUpdatePasswordResponse (WebData ())
    | UpdatedOldPassword String
    | UpdatedNewPassword String
      --------
    | UpdatedDeviationRadius Int
    | ReceivedUpdateDeviationRadiusResponse (WebData Int)
      --------
    | UpdateSchool
    | ReceivedUpdateSchoolResponse (WebData School)
    | UpdatedSchoolName String
    | UpdatedSchoolLocation { location : Location, radius : Float }



-- | UpdatedNewPassword String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form

        requests =
            model.requests
    in
    case msg of
        NoOp ->
            ( model, Cmd.none )

        Logout ->
            ( model
            , Cmd.batch
                [ -- sendLogout
                  Api.logout
                ]
            )

        ReceivedSchoolDetails schoolDetails ->
            case schoolDetails of
                Success school ->
                    ( { model | schoolDetailsRequest = schoolDetails }
                    , Cmd.batch
                        [ Ports.cleanMap ()
                        , Ports.initializeCustomMap { drawable = False, clickable = False }
                        , Ports.insertCircle { location = school.location, radius = school.radius }
                        , Models.Location.storeSchoolLocation school.location
                        ]
                    )

                _ ->
                    ( { model | schoolDetailsRequest = schoolDetails }, Cmd.none )

        SetOverlay overlay ->
            let
                updatedModel =
                    { model
                        | overlayType = overlay
                        , requests = emptyRequests model.schoolDetailsRequest
                    }
            in
            case model.schoolDetailsRequest of
                Success school ->
                    ( { updatedModel
                        | form =
                            { emptyForm | location = school.location, radius = school.radius, schoolName = school.name }
                      }
                    , if overlay /= Just Password then
                        Cmd.batch
                            [ Ports.cleanMap ()
                            , Ports.initializeCustomMap { drawable = False, clickable = overlay == Just School }
                            , Ports.insertCircle { location = school.location, radius = school.radius }
                            ]

                      else
                        Cmd.none
                    )

                _ ->
                    ( { updatedModel
                        | form =
                            emptyForm
                      }
                    , Cmd.none
                    )

        UpdatedOldPassword pass ->
            ( { model | form = { form | oldPassword = pass } }, Cmd.none )

        UpdatedNewPassword pass ->
            ( { model | form = { form | newPassword = pass } }, Cmd.none )

        SubmitNewPassword ->
            case validatePasswordForm form of
                Ok validForm ->
                    ( { model
                        | form = { form | problems = [] }
                        , requests = { requests | editPasswordRequest = Loading }
                      }
                    , submitUpdatePassword model.session validForm
                    )

                Err problems ->
                    ( { model | form = { form | problems = Errors.toClientSideErrors problems } }, Cmd.none )

        ReceivedUpdatePasswordResponse response ->
            let
                newModel =
                    { model | requests = { requests | editPasswordRequest = response } }
            in
            case response of
                Success _ ->
                    ( { newModel | overlayType = Nothing, requests = emptyRequests model.schoolDetailsRequest, form = emptyForm }, Cmd.none )

                Failure error ->
                    let
                        ( _, error_msg ) =
                            Errors.decodeErrors error

                        apiFormError =
                            Errors.toServerSideErrors
                                error

                        updatedForm =
                            { form | problems = form.problems ++ apiFormError }
                    in
                    ( { newModel | form = updatedForm }, error_msg )

                _ ->
                    ( { newModel | form = { form | problems = [] } }, Cmd.none )

        UpdateSchool ->
            case validateSchoolForm form of
                Ok validForm ->
                    ( { model
                        | form = { form | problems = [] }
                        , requests = { requests | editSchoolRequest = Loading }
                      }
                    , submitUpdateSchool model.session validForm
                    )

                Err problems ->
                    ( { model | form = { form | problems = Errors.toClientSideErrors problems } }, Cmd.none )

        ReceivedUpdateSchoolResponse response ->
            let
                newModel =
                    { model | requests = { requests | editSchoolRequest = response } }
            in
            case response of
                Success school ->
                    ( { newModel
                        | overlayType = Nothing
                        , schoolDetailsRequest = response
                        , requests = emptyRequests model.schoolDetailsRequest
                        , form = emptyForm
                      }
                    , Cmd.batch
                        [ Ports.cleanMap ()
                        , Ports.initializeCustomMap { drawable = False, clickable = False }
                        , Ports.insertCircle { location = school.location, radius = school.radius }
                        , Models.Location.storeSchoolLocation school.location
                        ]
                    )

                Failure error ->
                    let
                        ( _, error_msg ) =
                            Errors.decodeErrors error

                        apiFormError =
                            Errors.toServerSideErrors
                                error

                        updatedForm =
                            { form | problems = form.problems ++ apiFormError }
                    in
                    ( { newModel | form = updatedForm }, error_msg )

                _ ->
                    ( { newModel | form = { form | problems = [] } }, Cmd.none )

        UpdatedSchoolName schoolName ->
            ( { model | form = { form | schoolName = schoolName } }, Cmd.none )

        UpdatedSchoolLocation mapData ->
            ( { model | form = { form | location = mapData.location, radius = mapData.radius } }, Cmd.none )

        UpdatedDeviationRadius newDeviationRadius ->
            let
                updateDeviation =
                    requests.updateDeviation
            in
            ( { model
                | requests =
                    { requests
                        | updateDeviation =
                            { updateDeviation
                                | request = Loading
                                , sliderValue = newDeviationRadius
                            }
                    }
              }
            , updateDeviationRadius model.session newDeviationRadius
            )

        ReceivedUpdateDeviationRadiusResponse updateResponse ->
            let
                updateDeviation =
                    requests.updateDeviation

                updatedSchoolDetails value =
                    case model.schoolDetailsRequest of
                        Success school ->
                            Success { school | deviationRadius = value }

                        _ ->
                            model.schoolDetailsRequest
            in
            case updateResponse of
                Success value ->
                    ( { model
                        | requests =
                            { requests
                                | updateDeviation =
                                    { updateDeviation
                                        | request = updateResponse
                                        , sliderValue = value
                                    }
                            }
                        , schoolDetailsRequest = updatedSchoolDetails value
                      }
                    , Cmd.none
                    )

                _ ->
                    ( { model | requests = { requests | updateDeviation = { updateDeviation | request = updateResponse } } }, Cmd.none )



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    let
        schoolName =
            "schoolName"

        email =
            model.session
                |> Session.getCredentials
                |> Maybe.map .email
                |> Maybe.withDefault ""

        sectionDivider title =
            row [ spacing 8, width fill ]
                [ el [ height (px 2), width (fill |> maximum 20), Background.color Colors.sassyGrey ] none
                , el [ Style.overline, Font.size 14, Font.medium ] (text title)
                , el [ height (px 2), Background.color Colors.sassyGrey, width fill ] none
                ]
    in
    Element.column
        [ width fill
        , spacing 40
        , padding 30
        , height (px viewHeight)
        , scrollbarY
        , inFront (viewOverlay model viewHeight)
        ]
        [ Style.iconHeader Icons.settings "Settings"
        , column
            [ spacing 16, width fill ]
            [ sectionDivider "School Details"
            , WebDataView.view model.schoolDetailsRequest
                (\school ->
                    row [ width fill, spacing 20 ]
                        [ el
                            [ width (px 500)
                            , height (px 400)
                            , Background.color Colors.semiDarkness
                            ]
                            (if model.overlayType /= Just School then
                                StyledElement.googleMap [ width fill, height fill ]

                             else
                                none
                            )
                        , column [ alignTop, spacing 10 ]
                            [ column [ spacing 8 ]
                                [ el Style.captionStyle (text "School Name")
                                , text school.name
                                ]
                            , StyledElement.hoverButton
                                []
                                { title = "Edit School", onPress = Just (SetOverlay (Just School)), icon = Just Icons.edit }
                            ]
                        ]
                )
            ]
        , column [ spacing 16, width fill ]
            [ sectionDivider "Your Details"
            , column [ spacing 10, width (fill |> maximum 400) ]
                [ column [ spacing 8 ]
                    [ el Style.captionStyle (text "Email")
                    , text email
                    ]
                , row [ spacing 8 ]
                    [ column [ spacing 8 ]
                        [ el Style.captionStyle (text "Password")
                        , text "••••••••"
                        ]
                    , StyledElement.iconButton [ Background.color Colors.white ]
                        { iconAttrs = [ Colors.fillPurple ], onPress = Just (SetOverlay (Just Password)), icon = Icons.edit }
                    ]
                ]
            ]
        , WebDataView.view model.schoolDetailsRequest
            (\school ->
                column [ spacing 16, width fill ]
                    [ sectionDivider "Deviation DeviationRadius"
                    , viewSlider model school.deviationRadius
                    ]
            )
        , el [ height (px 100), width (px 100) ] none
        ]


viewSlider : Model -> Int -> Element Msg
viewSlider model deviationRadius =
    let
        max : Int
        max =
            3

        ticks : Element msg
        ticks =
            let
                createTick position =
                    el
                        [ width (px 2)
                        , height (px 8)
                        , centerY
                        , if position == deviationRadius then
                            Background.color (rgba 1 1 1 0)

                          else
                            Background.color Colors.purple
                        ]
                        none
            in
            row [ spaceEvenly, width fill, centerY ] (List.map createTick (List.range 0 max))
    in
    column
        [ paddingXY 10 0
        , alignBottom
        , height (px 93)
        , Background.color Colors.white
        , width (fill |> maximum 400)
        , spacing 10
        ]
        [ column [ spacing 4 ]
            [ el [ width fill ] (text "How far off route should the bus be allowed to travel")
            , el [ width fill ] (text "before it is flagged?")
            ]
        , el [ width (fillPortion 1), width (fillPortion 1) ] none
        , column [ width (fillPortion 40), spacing 8 ]
            [ row
                [ spacing 10
                , width (fill |> maximum 360)
                ]
                [ Input.slider
                    [ -- height (px 40),
                      -- "Track styling"
                      Element.behindContent
                        (row [ height fill, width fill, centerY, Element.behindContent ticks ]
                            [ Element.el
                                -- "Filled track"
                                [ width (fillPortion deviationRadius)
                                , height (px 3)
                                , Background.color Colors.purple
                                , Border.rounded 2
                                ]
                                Element.none
                            , Element.el
                                -- "Default track"
                                [ width (fillPortion (max - deviationRadius))
                                , height (px 3)
                                , alpha 0.38
                                , Background.color Colors.purple
                                , Border.rounded 2
                                ]
                                Element.none
                            ]
                        )
                    ]
                    { onChange = round >> UpdatedDeviationRadius
                    , label =
                        Input.labelHidden "Timeline Slider"
                    , min = 0
                    , max = Basics.toFloat max
                    , step = Just 1
                    , value = Basics.toFloat deviationRadius
                    , thumb =
                        Input.thumb
                            [ Background.color Colors.purple
                            , width (px 16)
                            , height (px 16)
                            , Border.rounded 8
                            , Border.solid
                            , Border.color (rgb 1 1 1)
                            , Border.width 2
                            ]
                    }
                , el [ centerY ]
                    (case model.requests.updateDeviation.request of
                        Success _ ->
                            Icons.done [ width (px 24), height (px 24), Colors.fillDarkGreen, alpha 1 ]

                        Loading ->
                            Icons.loading [ width (px 36), height (px 36) ]

                        Failure _ ->
                            Icons.close
                                [ width (px 36)
                                , height (px 36)
                                , Colors.fillErrorRed
                                , alpha 1
                                , onRight
                                    (el (Style.captionStyle ++ [ centerY, Font.color Colors.errorRed, alpha 1 ])
                                        (text "Are you offline?")
                                    )
                                ]

                        _ ->
                            none
                    )
                ]
            , row
                [ spaceEvenly
                , width fill
                , centerY
                , moveRight 64
                , width (fill |> maximum 320)
                ]
                (List.map
                    (\value ->
                        el ([ width fill, Font.center ] ++ Style.captionStyle) (text value)
                    )
                    [ "500 m", "1 km", "1.5 km" ]
                )
            ]
        ]


viewOverlay : Model -> Int -> Element Msg
viewOverlay model viewHeight =
    let
        overlayType =
            model.overlayType
    in
    el
        (Style.animatesAll
            :: width fill
            :: height (px viewHeight)
            :: paddingXY 40 30
            :: behindContent
                (Input.button
                    [ width fill
                    , height fill
                    , Background.color (Colors.withAlpha Colors.black 0.6)
                    , Style.blurredStyle
                    , Style.clickThrough
                    ]
                    { onPress = Just (SetOverlay Nothing)
                    , label = none
                    }
                )
            :: (if overlayType == Nothing then
                    [ alpha 0, Style.clickThrough ]

                else
                    [ alpha 1 ]
               )
        )
        (case overlayType of
            Nothing ->
                none

            Just overlay ->
                el [ Style.nonClickThrough, scrollbarY, centerX, centerY, Background.color Colors.white, Style.elevated2, Border.rounded 5 ]
                    (case overlay of
                        Password ->
                            updatePasswordForm model

                        School ->
                            updateSchoolForm model
                    )
        )


updatePasswordForm model =
    let
        problems =
            model.form.problems
    in
    column [ spacing 20, padding 40 ]
        [ el Style.header2Style (text "Change Password")
        , column [ spacing 20, width fill ]
            [ StyledElement.passwordInput [ width (fill |> minimum 300) ]
                { title = "Old Password"
                , caption = Nothing
                , errorCaption = Errors.inputErrorsFor problems "old_password" [ EmptyOldPassword ]
                , value = model.form.oldPassword
                , onChange = UpdatedOldPassword
                , placeholder = Nothing
                , ariaLabel = "Password input"
                , icon = Nothing
                , newPassword = False
                }
            , StyledElement.passwordInput [ width fill ]
                { title = "New Password"
                , caption = Nothing
                , errorCaption = Errors.inputErrorsFor problems "password" [ EmptyNewPassword ]
                , value = model.form.newPassword
                , onChange = UpdatedNewPassword
                , placeholder = Nothing
                , ariaLabel = "Password input"
                , icon = Nothing
                , newPassword = True
                }
            ]
        ]


updateSchoolForm model =
    let
        problems =
            model.form.problems
    in
    column [ spacing 20, padding 40 ]
        [ el Style.header2Style (text "Update School")
        , column [ spacing 20, width fill ]
            [ if model.overlayType == Just School then
                el [ width (px 500), height (px 400) ] (StyledElement.googleMap [])

              else
                none
            , StyledElement.textInput [ width fill ]
                { title = "School Name"
                , caption = Nothing
                , errorCaption = Errors.inputErrorsFor problems "name" [ EmptyNewPassword ]
                , value = model.form.schoolName
                , onChange = UpdatedSchoolName
                , placeholder = Nothing
                , ariaLabel = "Password input"
                , icon = Nothing
                }
            ]
        ]



--  TAB BAR ITEMS


tabBarItems model =
    case model.overlayType of
        Just Password ->
            case model.requests.editPasswordRequest of
                Failure _ ->
                    [ TabBar.Button
                        { title = "Cancel"
                        , icon = Icons.close
                        , onPress = SetOverlay Nothing
                        }
                    , TabBar.ErrorButton
                        { title = "Try Again"
                        , icon = Icons.save
                        , onPress = SubmitNewPassword
                        }
                    ]

                Loading ->
                    [ TabBar.LoadingButton
                        { title = ""
                        }
                    ]

                _ ->
                    [ TabBar.Button
                        { title = "Cancel"
                        , icon = Icons.close
                        , onPress = SetOverlay Nothing
                        }
                    , TabBar.Button
                        { title = "Save"
                        , icon = Icons.save
                        , onPress = SubmitNewPassword
                        }
                    ]

        Just School ->
            case model.requests.editSchoolRequest of
                Failure _ ->
                    [ TabBar.Button
                        { title = "Cancel"
                        , icon = Icons.close
                        , onPress = SetOverlay Nothing
                        }
                    , TabBar.ErrorButton
                        { title = "Try Again"
                        , icon = Icons.save
                        , onPress = UpdateSchool
                        }
                    ]

                Loading ->
                    [ TabBar.LoadingButton
                        { title = ""
                        }
                    ]

                _ ->
                    [ TabBar.Button
                        { title = "Cancel"
                        , icon = Icons.close
                        , onPress = SetOverlay Nothing
                        }
                    , TabBar.Button
                        { title = "Save"
                        , icon = Icons.save
                        , onPress = UpdateSchool
                        }
                    ]

        Nothing ->
            [ TabBar.Button
                { title = "Logout"
                , icon = Icons.exit
                , onPress = Logout
                }
            ]



--  HTTP


validatePasswordForm : Form -> Result (List ( Problem, String )) UpdatePasswordForm
validatePasswordForm form =
    let
        problems =
            List.concat
                [ if String.isEmpty (String.trim form.oldPassword) then
                    [ ( EmptyOldPassword, "Required" ) ]

                  else
                    []
                , if String.isEmpty (String.trim form.newPassword) then
                    [ ( EmptyNewPassword, "Required" ) ]

                  else
                    []
                ]
    in
    case problems of
        [] ->
            Ok
                { oldPassword = form.oldPassword
                , newPassword = form.newPassword
                }

        _ ->
            Err problems


submitUpdatePassword : Session -> UpdatePasswordForm -> Cmd Msg
submitUpdatePassword session form =
    let
        params =
            Encode.object
                [ ( "old_password", Encode.string form.oldPassword )
                , ( "new_password", Encode.string form.newPassword )
                ]
    in
    Api.patch session Endpoint.updatePassword params decoder
        |> Cmd.map ReceivedUpdatePasswordResponse


validateSchoolForm : Form -> Result (List ( Problem, String )) UpdateSchoolForm
validateSchoolForm form =
    let
        problems =
            List.concat
                [ if String.isEmpty (String.trim form.schoolName) then
                    [ ( EmptySchoolName, "Required" ) ]

                  else
                    []
                ]
    in
    case problems of
        [] ->
            Ok
                { location = form.location
                , radius = form.radius
                , schoolName = form.schoolName
                }

        _ ->
            Err problems


submitUpdateSchool : Session -> UpdateSchoolForm -> Cmd Msg
submitUpdateSchool session form =
    let
        params =
            Encode.object
                [ ( "lat", Encode.float form.location.lat )
                , ( "lng", Encode.float form.location.lng )
                , ( "name", Encode.string form.schoolName )
                , ( "radius", Encode.float form.radius )
                ]
    in
    Api.patch session Endpoint.schoolDetails params Models.School.schoolDecoder
        |> Cmd.map ReceivedUpdateSchoolResponse


fetchSchoolDetails : Session -> Cmd Msg
fetchSchoolDetails session =
    Api.get session Endpoint.schoolDetails Models.School.schoolDecoder
        |> Cmd.map ReceivedSchoolDetails


updateDeviationRadius session newDeviationRadius =
    let
        params =
            Encode.object
                [ ( "deviation_radius", Encode.int newDeviationRadius )
                ]
    in
    Api.patch session Endpoint.schoolDetails params (Models.School.schoolDecoder |> Decode.map .deviationRadius)
        |> Cmd.map ReceivedUpdateDeviationRadiusResponse


decoder : Decoder ()
decoder =
    Decode.succeed ()


subscriptions : Model -> Sub Msg
subscriptions model =
    Ports.receivedMapClickLocation
        (\x ->
            x
                |> Maybe.map
                    (\s ->
                        UpdatedSchoolLocation
                            { location = Location s.lng s.lat, radius = s.radius }
                    )
                |> Maybe.withDefault NoOp
        )
