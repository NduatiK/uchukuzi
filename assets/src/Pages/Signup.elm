module Pages.Signup exposing (Model, Msg, init, update, view)

import Api
import Api.Endpoint as Endpoint
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Http
import Icons
import Json.Decode as Decode exposing (Decoder, float, int, list, string)
import Json.Decode.Pipeline exposing (hardcoded, optional, required, resolve)
import Json.Encode as Encode
import RemoteData exposing (..)
import Route exposing (LoginRedirect, Route)
import Session exposing (Session)
import Style
import StyledElement exposing (Errors)
import Utils.Validator exposing (..)



-- MODEL


type alias Model =
    { session : Session
    , form : Form
    , status : WebData Session.Cred
    }


type Email
    = Email String


type Password
    = Password String


type Name
    = Name String


type alias ManagerDetailsForm =
    { firstName : Name
    , lastName : Name
    , schoolName : Name
    , email : Email
    , password : Password
    }


type alias SchoolDetailsForm =
    { schoolName : Name
    , location : Name
    }


type Problem
    = EmptyFirstName
    | EmptySchoolName
    | EmptySchoolLocation
    | EmptyLastName
    | InvalidEmail
    | PasswordIsEmpty
    | PasswordIsTooShort


type Pages
    = ManagerDetails
    | SchoolDetails


pageAfter : Pages -> Maybe Pages
pageAfter page =
    case page of
        ManagerDetails ->
            Just SchoolDetails

        SchoolDetails ->
            Nothing


pageBefore : Pages -> Maybe Pages
pageBefore page =
    case page of
        SchoolDetails ->
            Just ManagerDetails

        ManagerDetails ->
            Nothing


type alias Form =
    { manager : ManagerDetailsForm
    , school : SchoolDetailsForm
    , page : Pages
    , problems : List (Errors Problem)
    }


type alias ValidForm =
    { firstName : String
    , lastName : String
    , schoolName : String
    , schoolLocation : String
    , email : String
    , password : String
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( Model session
        { manager =
            { firstName = Name ""
            , lastName = Name ""
            , schoolName = Name ""
            , email = Email ""
            , password = Password ""
            }
        , school =
            { schoolName = Name ""
            , location = Name ""
            }
        , page = ManagerDetails
        , problems = []
        }
        NotAsked
    , Cmd.none
    )



-- UPDATE


type Msg
    = UpdatedFirstName Name
    | UpdatedLastName Name
    | UpdatedSchoolName Name
    | UpdatedEmail Email
    | UpdatedPassword Password
    | NextForm
    | PreviousForm
    | SubmittedForm
    | SignupResponse (WebData Session.Cred)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form

        manager =
            form.manager

        school =
            form.school
    in
    case msg of
        UpdatedFirstName name ->
            ( { model
                | form =
                    { form | manager = { manager | firstName = name } }
              }
            , Cmd.none
            )

        UpdatedLastName name ->
            ( { model
                | form =
                    { form | manager = { manager | lastName = name } }
              }
            , Cmd.none
            )

        UpdatedSchoolName name ->
            ( { model
                | form =
                    { form | school = { school | schoolName = name } }
              }
            , Cmd.none
            )

        UpdatedPassword password ->
            ( { model
                | form =
                    { form | manager = { manager | password = password } }
              }
            , Cmd.none
            )

        UpdatedEmail email ->
            ( { model
                | form =
                    { form | manager = { manager | email = email } }
              }
            , Cmd.none
            )

        NextForm ->
            case pageAfter form.page of
                Nothing ->
                    ( model, Cmd.none )

                Just page ->
                    case validateForm form of
                        Ok _ ->
                            ( { model | form = { form | page = page } }, Cmd.none )

                        Err problems ->
                            ( { model | form = { form | problems = StyledElement.toClientSideErrors problems } }, Cmd.none )

        PreviousForm ->
            case pageBefore form.page of
                Nothing ->
                    ( model, Cmd.none )

                Just page ->
                    ( { model | form = { form | page = page } }, Cmd.none )

        SubmittedForm ->
            case validateForm form of
                Ok validForm ->
                    ( { model | form = { form | problems = [] } }, signup model.session validForm )

                Err problems ->
                    ( { model | form = { form | problems = StyledElement.toClientSideErrors problems } }, Cmd.none )

        SignupResponse requestStatus ->
            let
                updatedModel =
                    { model | status = requestStatus }
            in
            updateStatus updatedModel requestStatus


updateStatus : Model -> WebData Session.Cred -> ( Model, Cmd Msg )
updateStatus model msg =
    case msg of
        Loading ->
            ( model, Cmd.none )

        Failure error ->
            let
                apiError =
                    Api.decodeErrors error

                apiFormErrors =
                    StyledElement.toServerSideErrors
                        (Api.decodeFormErrors
                            [ "phone_number"
                            , "email"
                            , "name"
                            , "password"
                            ]
                            error
                        )

                form =
                    model.form

                updatedForm =
                    { form | problems = form.problems ++ apiFormErrors }
            in
            ( { model | form = updatedForm }, Api.handleError model apiError )

        NotAsked ->
            ( model, Cmd.none )

        Success creds ->
            ( model
            , Cmd.batch
                [ Route.rerouteTo model (Route.Login (Just Route.ConfirmEmail))
                , Api.storeCredentials creds
                ]
            )



-- VIEW


view : Model -> Element Msg
view model =
    let
        formPage =
            case model.form.page of
                ManagerDetails ->
                    viewManagerForm

                SchoolDetails ->
                    viewSchoolForm

        -- option2 ->
    in
    -- column [ centerX, centerY, width (fill |> maximum 500), spacing 10, paddingXY 30 0 ]
    column [ centerX, centerY, spacing 10, paddingXY 30 0 ]
        [ el (alignLeft :: Style.headerStyle) (text "Sign Up")
        , formPage model
        , spacer
        , spacer
        , viewButtons model
        , viewDivider
        , viewFooter
        , el [ height (fill |> minimum 100) ] none
        ]


spacer : Element msg
spacer =
    el [] none


formPageHeader : String -> String -> Element msg
formPageHeader name pageNumber =
    el (alignLeft :: Style.header2Style)
        (paragraph [ spacing 10 ]
            [ text name
            , el (paddingXY 10 0 :: Style.captionLabelStyle) (text pageNumber)
            ]
        )


viewSchoolForm : Model -> Element Msg
viewSchoolForm model =
    let
        form =
            model.form

        errorMapper =
            StyledElement.inputErrorsFor form.problems
    in
    column [ centerX, alignTop, width (fill |> maximum 600), spacing 10 ]
        [ formPageHeader "School Details" "(2/2)"
        , StyledElement.textInput [ centerX ]
            { title = "School Name"
            , caption = Just "This is the name that will be visible to parents and students"
            , errorCaption = errorMapper "school_name" [ EmptySchoolName ]
            , value = nameString form.school.schoolName
            , onChange = Name >> UpdatedSchoolName
            , placeholder = Nothing
            , ariaLabel = "School name input"
            , icon = Nothing
            }
        , spacer
        , el
            [ height (px 400)
            , width (px 600)
            , Background.color (rgb 0 0 1)
            ]
            none
        , spacer
        ]


viewManagerForm : Model -> Element Msg
viewManagerForm model =
    let
        form =
            model.form

        errorMapper =
            StyledElement.inputErrorsFor form.problems
    in
    column [ centerX, alignTop, width (fill |> maximum 500), spacing 10 ]
        [ formPageHeader "Your Details" "(1/2)"
        , row [ spacing 10, width fill ]
            [ StyledElement.textInput [ alignTop ]
                { title = "First Name"
                , caption = Nothing
                , errorCaption =
                    errorMapper "name"
                        [ EmptyFirstName ]
                , value = nameString form.manager.firstName
                , onChange = Name >> UpdatedFirstName
                , placeholder = Nothing
                , ariaLabel = "First name input"
                , icon = Nothing
                }
            , StyledElement.textInput [ alignTop ]
                { title = "Last Name"
                , caption = Nothing
                , errorCaption =
                    errorMapper "name"
                        [ EmptyLastName ]
                , value = nameString form.manager.lastName
                , onChange = Name >> UpdatedLastName
                , placeholder = Nothing
                , ariaLabel = "Last name input"
                , icon = Nothing
                }
            ]
        , el Style.captionLabelStyle (text "Your official name")
        , spacer
        , StyledElement.emailInput [ centerX ]
            { title = "Email Address"
            , caption = Just "Your official email address"
            , errorCaption = errorMapper "email" [ InvalidEmail ]
            , value = emailString form.manager.email
            , onChange = Email >> UpdatedEmail
            , placeholder = Nothing
            , ariaLabel = "Email input"
            , icon = Nothing
            }
        , spacer
        , StyledElement.passwordInput [ centerX ]
            { title = "New Password"
            , caption = Nothing
            , errorCaption =
                errorMapper "password"
                    [ PasswordIsEmpty
                    , PasswordIsTooShort
                    ]
            , value = passwordString form.manager.password
            , onChange = Password >> UpdatedPassword
            , placeholder = Nothing
            , ariaLabel = "Password input"
            , icon = Nothing
            , newPassword = True
            }
        ]


viewFooter : Element msg
viewFooter =
    column []
        [ wrappedRow [ spacing 8 ]
            [ el (Font.size 15 :: Style.labelStyle)
                (text "Already have an account?")
            , row [ spacing 8 ]
                [ StyledElement.textLink [ Font.color Style.darkGreenColor, Font.size 15, Font.bold ] { label = text "Login", route = Route.Login Nothing }
                , Icons.chevronDown [ rotate (-pi / 2) ]
                ]
            ]
        ]


viewDivider : Element msg
viewDivider =
    el
        [ width (fill |> maximum 480)
        , padding 10
        , spacing 7
        , Border.widthEach
            { bottom = 2
            , left = 0
            , right = 0
            , top = 0
            }
        , Border.color (rgb255 243 243 243)
        ]
        Element.none


validateForm : Form -> Result (List ( Problem, String )) ValidForm
validateForm form =
    let
        managerProblems manager =
            List.concat
                [ if isValidEmail (emailString manager.email) then
                    []

                  else
                    [ ( InvalidEmail, "There's something wrong with this email" ) ]
                , if manager.firstName == Name "" then
                    [ ( EmptyFirstName, "Required" ) ]

                  else
                    []
                , if manager.lastName == Name "" then
                    [ ( EmptyLastName, "Required" ) ]

                  else
                    []
                , if String.isEmpty (passwordString manager.password) then
                    [ ( PasswordIsEmpty, "A password is required" ) ]

                  else if String.length (passwordString manager.password) < minimumPasswordLength then
                    [ ( PasswordIsTooShort, "Your password must be at least " ++ String.fromInt minimumPasswordLength ++ " characters long" ) ]

                  else
                    []
                ]

        schoolProblems school =
            List.concat
                [ if school.schoolName == Name "" then
                    [ ( EmptySchoolName, "Required" ) ]

                  else
                    []
                , if school.location == Name "" then
                    [ ( EmptySchoolLocation, "Required" ) ]

                  else
                    []
                ]

        problems =
            case form.page of
                ManagerDetails ->
                    managerProblems form.manager

                SchoolDetails ->
                    schoolProblems form.school
    in
    case problems of
        [] ->
            Ok
                { firstName = nameString form.manager.firstName
                , lastName = nameString form.manager.lastName
                , email = emailString form.manager.email
                , password = passwordString form.manager.password
                , schoolLocation = nameString form.school.location
                , schoolName = nameString form.school.schoolName
                }

        _ ->
            Err problems


emailString : Email -> String
emailString (Email str) =
    str


passwordString : Password -> String
passwordString (Password str) =
    str


nameString : Name -> String
nameString (Name str) =
    str


minimumPasswordLength : Int
minimumPasswordLength =
    6


viewButtons : Model -> Element Msg
viewButtons model =
    case model.status of
        Loading ->
            Icons.loading [ alignRight, width (px 46), height (px 46) ]

        _ ->
            row [ width fill ]
                [ if model.form.page == SchoolDetails then
                    StyledElement.button
                        [ alignLeft, Background.color (rgba 0 0 0 0), Font.color Style.darkTextColor ]
                        { label = text "Back"
                        , onPress = Just PreviousForm
                        }

                  else
                    none
                , StyledElement.button [ alignRight ]
                    { label =
                        text
                            (if model.form.page == SchoolDetails then
                                "Done"

                             else
                                "Next"
                            )
                    , onPress =
                        Just
                            (if model.form.page == SchoolDetails then
                                SubmittedForm

                             else
                                NextForm
                            )
                    }
                ]


loginDecoder : Decoder String
loginDecoder =
    Decode.field "message" string


signup : Session -> ValidForm -> Cmd Msg
signup session form =
    let
        managerParams =
            Encode.object
                [ ( "email", Encode.string form.email )
                , ( "name", Encode.string (form.firstName ++ " " ++ form.lastName) )
                , ( "password", Encode.string form.password )
                ]

        params =
            Encode.object
                [ ( "manager", managerParams )
                , ( "school"
                  , Encode.object
                        [ ( "school_name", Encode.string form.schoolName )
                        , ( "school_location", Encode.string form.schoolLocation )
                        ]
                  )
                ]
                |> Http.jsonBody
    in
    Api.post session Endpoint.signup params Api.credDecoder
        |> Cmd.map SignupResponse
