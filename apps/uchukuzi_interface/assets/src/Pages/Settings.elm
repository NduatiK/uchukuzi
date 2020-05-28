module Pages.Settings exposing (Model, Msg, init, tabBarItems, update, view)

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


emptyRequests =
    { editPasswordRequest = NotAsked
    , editSchoolRequest = NotAsked
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , overlayType = Nothing
      , form = emptyForm
      , schoolDetailsRequest = Loading
      , requests =
            emptyRequests
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
                        , requests = emptyRequests
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
                    ( { newModel | overlayType = Nothing, requests = emptyRequests, form = emptyForm }, Cmd.none )

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
            ( { model
                | schoolDetailsRequest =
                    case response of
                        Success _ ->
                            response

                        _ ->
                            model.schoolDetailsRequest
              }
            , Cmd.none
            )

        UpdatedSchoolName schoolName ->
            ( { model | form = { form | schoolName = schoolName } }, Cmd.none )

        UpdatedSchoolLocation mapData ->
            ( { model | form = { form | location = mapData.location, radius = mapData.radius } }, Cmd.none )



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    let
        schoolName =
            "schoolName"

        email =
            model.session
                |> Session.getCredentials
                |> Maybe.andThen (.email >> Just)
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
        , paddingEach { edges | left = 50, right = 30, top = 30, bottom = 30 }
        , height fill
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
                            , Background.color (rgb255 115 115 115)
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
            Debug.log "" model.form.problems
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
            Debug.log "" model.form.problems
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
    Api.patch session Endpoint.schoolDetails params decoder
        |> Cmd.map ReceivedUpdatePasswordResponse


fetchSchoolDetails : Session -> Cmd Msg
fetchSchoolDetails session =
    Api.get session Endpoint.schoolDetails Models.School.schoolDecoder
        |> Cmd.map ReceivedSchoolDetails


decoder : Decoder ()
decoder =
    Decode.succeed ()
