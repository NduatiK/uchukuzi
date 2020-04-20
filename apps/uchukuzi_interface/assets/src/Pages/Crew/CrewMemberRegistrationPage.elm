module Pages.Crew.CrewMemberRegistrationPage exposing (Model, Msg, init, subscriptions, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Errors exposing (Errors)
import Html.Events exposing (..)
import Http
import Icons
import Json.Decode as Decode exposing (Decoder, string)
import Json.Encode as Encode
import Models.CrewMember exposing (CrewMember, Role(..))
import Navigation
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import StyledElement.DropDown as Dropdown
import Task
import Utils.Validator as Validator
import Views.Heading exposing (viewHeading)



-- MODEL


type Field
    = Name String
    | Email String
    | PhoneNumber String
    | Role (Maybe Role)


type alias Model =
    { session : Session
    , form : Form
    , roleDropdownState : Dropdown.State Role
    , requestState : WebData ()
    , editState : Maybe EditState
    }


isEditing : Model -> Bool
isEditing model =
    model.editState /= Nothing


type alias EditState =
    { requestState : WebData CrewMember
    , crewMemberID : Int
    }


type alias Form =
    { name : String
    , email : String
    , phoneNumber : String
    , role : Maybe Role
    , problems : List (Errors.Errors Problem)
    }


type Problem
    = EmptyName
    | EmptyEmail
    | InvalidEmail
    | EmptyPhoneNumber
    | InvalidPhoneNumber
    | EmptyRole


type alias ValidForm =
    { name : String
    , email : String
    , phoneNumber : String
    , role : String
    }


roleToString : Role -> String
roleToString role =
    case role of
        Driver ->
            "Driver"

        Assistant ->
            "Assistant"


init : Session -> Maybe Int -> ( Model, Cmd Msg )
init session id =
    ( { session = session
      , form =
            { name = ""
            , email = ""
            , phoneNumber = ""
            , role = Just Assistant
            , problems = []
            }
      , roleDropdownState = Dropdown.init "rolesDropdown"
      , requestState = NotAsked
      , editState =
            Maybe.andThen (EditState Loading >> Just) id
      }
    , Cmd.batch
        [ Task.succeed (RoleDropdownMsg (Dropdown.selectOption Assistant)) |> Task.perform identity
        , case id of
            Just id_ ->
                fetchCrewMember session id_

            Nothing ->
                Cmd.none
        ]
    )



-- UPDATE


type Msg
    = Changed Field
    | SubmitButtonMsg
    | ServerResponse (WebData ())
    | CrewMemberResponse (WebData CrewMember)
    | RoleDropdownMsg (Dropdown.Msg Role)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Changed field ->
            updateField field model

        RoleDropdownMsg subMsg ->
            let
                ( _, config, options ) =
                    routeDropDown model

                ( state, cmd ) =
                    Dropdown.update config subMsg model.roleDropdownState options
            in
            ( { model | roleDropdownState = state }, cmd )

        SubmitButtonMsg ->
            let
                form =
                    model.form
            in
            case validateForm form of
                Ok validForm ->
                    ( { model
                        | form = { form | problems = [] }
                        , requestState = Loading
                      }
                    , submit model.session validForm (Maybe.andThen (.crewMemberID >> Just) model.editState)
                    )

                Err problems ->
                    ( { model | form = { form | problems = Errors.toClientSideErrors problems } }, Cmd.none )

        ServerResponse response ->
            let
                newModel =
                    { model | requestState = response }

                form =
                    newModel.form
            in
            case response of
                Success bus_id ->
                    ( newModel, Navigation.rerouteTo newModel Navigation.CrewMembers )

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

        CrewMemberResponse response ->
            let
                editState =
                    model.editState

                newModel =
                    { model | editState = Maybe.andThen (\x -> Just { x | requestState = response }) editState }
            in
            case response of
                Success crewMember ->
                    let
                        form =
                            { name = crewMember.name
                            , email = crewMember.email
                            , phoneNumber = crewMember.phoneNumber
                            , role = Just crewMember.role
                            , problems = []
                            }
                    in
                    ( { newModel | form = form }, Task.succeed (RoleDropdownMsg (Dropdown.selectOption crewMember.role)) |> Task.perform identity )

                _ ->
                    ( newModel, Cmd.none )


updateField : Field -> Model -> ( Model, Cmd Msg )
updateField field model =
    let
        form =
            model.form
    in
    case field of
        Name name ->
            let
                updated_form =
                    { form | name = name }
            in
            ( { model | form = updated_form }, Cmd.none )

        PhoneNumber phoneNumber ->
            let
                updated_form =
                    { form | phoneNumber = phoneNumber }
            in
            ( { model | form = updated_form }, Cmd.none )

        Email email ->
            let
                updated_form =
                    { form | email = email }
            in
            ( { model | form = updated_form }, Cmd.none )

        Role role ->
            let
                updated_form =
                    { form | role = role }
            in
            ( { model | form = updated_form }, Cmd.none )



-- VIEW


view : Model -> Element Msg
view model =
    row [ width fill, height fill ]
        [ Element.column
            [ width fill, spacing 40, paddingXY 24 8, alignTop, height fill ]
            [ if isEditing model then
                viewHeading "Edit Crew Member" Nothing

              else
                viewHeading "Add a Crew Member" Nothing
            , case model.editState of
                Just state ->
                    case state.requestState of
                        Success _ ->
                            viewForm model

                        Loading ->
                            el [ width fill, height fill ] (Icons.loading [ centerX, centerY ])

                        _ ->
                            el (centerX :: centerY :: Style.labelStyle) (paragraph [] [ text "Something went wrong, please reload the page" ])

                Nothing ->
                    viewForm model
            ]
        ]


viewForm : Model -> Element Msg
viewForm model =
    let
        form =
            model.form
    in
    -- column [ spacing 50, paddingEach { edges | bottom = 100 } ]
    column
        [ spacing 32, width (fill |> minimum 300 |> maximum 300), alignTop ]
        [ viewNameInput form.problems form.name
        , viewEmailInput form.problems form.email
        , viewPhoneInput form.problems form.phoneNumber
        , viewRoleDropDown model
        , viewButton model.requestState
        ]


viewNameInput : List (Errors Problem) -> String -> Element Msg
viewNameInput problems name =
    StyledElement.emailInput
        [ width
            (fill
                |> maximum 300
            )
        ]
        { ariaLabel = "Name"
        , caption = Nothing
        , errorCaption = Errors.inputErrorsFor problems "name" [ EmptyName ]
        , icon = Nothing
        , onChange = Name >> Changed
        , placeholder = Nothing
        , title = "Name"
        , value = name
        }


viewEmailInput : List (Errors Problem) -> String -> Element Msg
viewEmailInput problems email =
    StyledElement.emailInput
        [ width
            (fill
                |> maximum 300
            )
        ]
        { ariaLabel = "Email Address"
        , caption = Just "Used to connect the parent to the mobile app"
        , errorCaption = Errors.inputErrorsFor problems "email" [ EmptyEmail, InvalidEmail ]
        , icon = Just Icons.email
        , onChange = Email >> Changed
        , placeholder = Nothing
        , title = "Email"
        , value = email
        }


viewPhoneInput : List (Errors Problem) -> String -> Element Msg
viewPhoneInput problems phone_number =
    StyledElement.textInput
        [ alignTop
        , width
            (fill
                |> maximum 300
            )
        ]
        { ariaLabel = "'s Phone Number"
        , caption = Nothing
        , errorCaption = Errors.inputErrorsFor problems "phone_number" [ EmptyPhoneNumber, InvalidPhoneNumber ]
        , icon = Just Icons.phone
        , onChange = PhoneNumber >> Changed
        , placeholder = Nothing
        , title = "Phone Number"
        , value = phone_number
        }


viewButton : WebData a -> Element Msg
viewButton requestState =
    let
        buttonView =
            case requestState of
                Loading ->
                    Icons.loading [ alignRight, width (px 46), height (px 46) ]

                Failure _ ->
                    StyledElement.button
                        [ alignRight, Background.color Colors.errorRed ]
                        { label =
                            row [ spacing 8 ]
                                [ el [ centerY ] (text "Try Again")
                                ]
                        , onPress = Just SubmitButtonMsg
                        }

                _ ->
                    StyledElement.button [ alignRight ]
                        { onPress = Just SubmitButtonMsg
                        , label = text "Submit"
                        }
    in
    el (Style.labelStyle ++ [ width fill ])
        buttonView


routeDropDown : Model -> ( Element Msg, Dropdown.Config Role Msg, List Role )
routeDropDown model =
    StyledElement.dropDown
        [ width
            (fill
                |> maximum 300
            )
        , alignTop
        ]
        { ariaLabel = "Select role dropdown"
        , caption = Nothing
        , prompt = Nothing
        , dropDownMsg = RoleDropdownMsg
        , dropdownState = model.roleDropdownState
        , errorCaption = Nothing
        , icon = Nothing
        , onSelect = Role >> Changed
        , options = [ Assistant, Driver ]
        , title = "Role"
        , toString = roleToString
        , isLoading = False
        }


viewRoleDropDown : Model -> Element Msg
viewRoleDropDown model =
    case routeDropDown model of
        ( dropDown, _, _ ) ->
            dropDown


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        []


validateForm : Form -> Result (List ( Problem, String )) ValidForm
validateForm form =
    let
        problems =
            List.concat
                [ if String.isEmpty (String.trim form.name) then
                    [ ( EmptyName, "Required" ) ]

                  else
                    []
                , if String.isEmpty (String.trim form.email) then
                    [ ( EmptyEmail, "Required" ) ]

                  else if not (Validator.isValidEmail form.email) then
                    [ ( InvalidEmail, "There's something wrong with this email" ) ]

                  else
                    []
                , if String.isEmpty (String.trim form.phoneNumber) then
                    [ ( EmptyPhoneNumber, "Required" ) ]

                  else if not (Validator.isValidPhoneNumber form.phoneNumber) then
                    [ ( InvalidPhoneNumber, "There's something wrong with this phone number" ) ]

                  else
                    []
                ]
    in
    case ( problems, form.role ) of
        ( [], Just role ) ->
            Ok
                { name = form.name
                , email = form.email
                , phoneNumber = form.phoneNumber
                , role = String.toLower (roleToString role)
                }

        ( _, Nothing ) ->
            Err (( EmptyRole, "Required" ) :: problems)

        _ ->
            Err problems


submit : Session -> ValidForm -> Maybe Int -> Cmd Msg
submit session form editingID =
    let
        params =
            Encode.object
                [ ( "name", Encode.string form.name )
                , ( "phone_number", Encode.string form.phoneNumber )
                , ( "email", Encode.string form.email )
                , ( "role", Encode.string form.role )
                ]
                |> Http.jsonBody
    in
    case editingID of
        Just id ->
            Api.patch session (Endpoint.crewMember id) params decoder
                |> Cmd.map ServerResponse

        Nothing ->
            Api.post session Endpoint.crewMembers params decoder
                |> Cmd.map ServerResponse


decoder : Decoder ()
decoder =
    Decode.succeed ()


fetchCrewMember session id =
    Api.get session (Endpoint.crewMember id) Models.CrewMember.crewDecoder
        |> Cmd.map CrewMemberResponse