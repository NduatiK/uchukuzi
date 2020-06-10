module Pages.Signup exposing (Model, Msg, init, subscriptions, update, view)

import Api exposing (SuccessfulLogin, loginDecoder)
import Api.Endpoint as Endpoint
import Browser.Dom as Dom
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Errors exposing (Errors, InputError)
import Html.Attributes exposing (id)
import Icons
import Json.Decode as Decode exposing (Decoder, float, int, list, string)
import Json.Decode.Pipeline exposing (hardcoded, optional, required, resolve)
import Json.Encode as Encode
import Models.Location as Location exposing (Location)
import Navigation exposing (LoginRedirect, Route)
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style
import StyledElement
import Task
import Utils.Validator exposing (..)



-- MODEL


type alias Model =
    { session : Session
    , form : Form
    , status : WebData SuccessfulLogin
    , loadingGeocode : Bool
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
    , email : Email
    , password : Password
    }


type alias ValidManagerForm =
    { name : String
    , email : String
    , password : String
    }


type alias SchoolDetailsForm =
    { schoolName : Name
    , perimeter :
        Maybe
            { location : Location
            , radius : Float
            }
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


type alias Form =
    { manager : ManagerDetailsForm
    , school : SchoolDetailsForm
    , page : Pages
    , problems : List (Errors Problem)
    }


type alias ValidSchoolForm =
    { schoolName : String
    , schoolLocation :
        { location : Location
        , radius : Float
        }
    }


type alias ValidForm =
    { manager : ValidManagerForm
    , school : ValidSchoolForm
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( Model session
        { manager =
            { firstName = Name ""
            , lastName = Name ""
            , email = Email ""
            , password = Password ""
            }
        , school =
            { schoolName = Name ""
            , perimeter = Nothing
            }
        , page = ManagerDetails
        , problems = []
        }
        NotAsked
        False
    , Cmd.none
    )



-- UPDATE


type Msg
    = UpdatedFirstName Name
    | UpdatedLastName Name
    | UpdatedSchoolName Name
    | UpdatedEmail Email
    | UpdatedPassword Password
    | RequestGeoLocation
    | LocationSelected (Maybe { lat : Float, lng : Float, radius : Float })
    | ToManagerForm
    | ToSchoolForm
    | NoOp
    | SubmittedForm
    | ReceivedSignupResponse (WebData SuccessfulLogin)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form

        manager =
            form.manager

        school =
            form.school

        updateManager manager_ model_ =
            { model_ | form = { form | manager = manager_ } }

        updateSchool school_ model_ =
            { model_ | form = { form | school = school_ } }

        updateProblems problems model_ =
            { model_ | form = { form | problems = problems } }
    in
    case msg of
        UpdatedFirstName name ->
            ( model |> updateManager { manager | firstName = name }
            , Cmd.none
            )

        UpdatedLastName name ->
            ( model |> updateManager { manager | lastName = name }
            , Cmd.none
            )

        UpdatedPassword password ->
            ( model |> updateManager { manager | password = password }
            , Cmd.none
            )

        UpdatedEmail email ->
            ( model |> updateManager { manager | email = email }
            , Cmd.none
            )

        UpdatedSchoolName name ->
            ( model |> updateSchool { school | schoolName = name }
            , Cmd.none
            )

        RequestGeoLocation ->
            ( { model | loadingGeocode = True }, Ports.requestGeoLocation () )

        LocationSelected perimeter ->
            let
                updatedPerimeter =
                    perimeter
                        |> Maybe.map
                            (\p ->
                                { location =
                                    { lat = p.lat
                                    , lng = p.lng
                                    }
                                , radius = p.radius
                                }
                            )
            in
            ( model
                |> updateSchool { school | perimeter = updatedPerimeter }
                |> (\m -> { m | loadingGeocode = False })
            , Cmd.none
            )

        ToSchoolForm ->
            case validateManagerForm form.manager of
                Ok _ ->
                    ( { model | form = { form | page = SchoolDetails } }
                    , Cmd.batch
                        [ Ports.initializeCustomMap { drawable = False, clickable = True }
                        , Task.attempt (always NoOp) (Dom.focus "school-name-input")
                        ]
                    )

                Err problems ->
                    ( model |> updateProblems (Errors.toValidationErrors problems)
                    , Cmd.none
                    )

        ToManagerForm ->
            ( { model | form = { form | page = ManagerDetails } }, Cmd.none )

        SubmittedForm ->
            case validateForm form of
                Ok validForm ->
                    ( model |> updateProblems []
                    , signup model.session validForm
                    )

                Err problems ->
                    ( model |> updateProblems (Errors.toValidationErrors problems)
                    , Cmd.none
                    )

        ReceivedSignupResponse requestStatus ->
            let
                updatedModel =
                    { model | status = requestStatus }
            in
            -- updateStatus updatedModel requestStatus
            case requestStatus of
                Failure error ->
                    let
                        apiFormErrors =
                            Errors.toServerSideErrors error

                        updatedForm =
                            { form | problems = form.problems ++ apiFormErrors }
                    in
                    ( { model | form = updatedForm }, Errors.toMsg error )

                Success data ->
                    ( model
                    , Cmd.batch
                        [ Navigation.rerouteTo model (Navigation.Login (Just Navigation.ConfirmEmail))
                        , Location.storeSchoolLocation data.location
                        ]
                    )

                _ ->
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )



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
            , el (paddingXY 10 0 :: Style.captionStyle) (text pageNumber)
            ]
        )


viewSchoolForm : Model -> Element Msg
viewSchoolForm model =
    let
        form =
            model.form

        errorMapper =
            Errors.captionFor form.problems

        hasMapError =
            List.any
                (\x ->
                    case x of
                        Errors.ValidationError y _ ->
                            y == EmptySchoolLocation

                        _ ->
                            False
                )
                form.problems

        mapCaptionStyle =
            if hasMapError then
                Style.errorStyle

            else
                Style.captionStyle

        mapBorderStyle =
            if hasMapError then
                [ Border.color Colors.errorRed, Border.width 2, padding 2 ]

            else
                [ Border.color Colors.white, Border.width 2, padding 2 ]
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
        , el mapBorderStyle (viewMap model.loadingGeocode)
        , row [ spacing 8 ]
            [ el mapCaptionStyle (text "Click on your school to mark its location")
            , Icons.help
                [ width (px 16)
                , height (px 16)
                , alpha 1
                , Element.pointer
                , inFront
                    (el
                        [ centerX
                        , alpha 0
                        , mouseOver [ alpha 1 ]
                        ]
                        (el ([ moveDown 24, Background.color Colors.white, Style.elevated2, padding 8, mouseOver [ alpha 0 ] ] ++ Style.captionStyle)
                            (text "This allows us to know when your vehicle has left or arrived at the school compound")
                        )
                    )
                ]
            ]
        , spacer
        ]


viewMap : Bool -> Element Msg
viewMap isLoading =
    let
        loadingView =
            if isLoading then
                Icons.loading [ alignRight, width (px 46), height (px 46) ]

            else
                StyledElement.button
                    [ Background.color Colors.teal, Font.color Colors.darkText, padding 50 ]
                    { label = text "Use my location"
                    , onPress = Just RequestGeoLocation
                    }
    in
    el
        [ inFront
            (el [ padding 20, alignBottom, alignRight ] loadingView)
        ]
        (StyledElement.googleMap
            [ height (px 400)
            , width (px 600)
            ]
        )


viewManagerForm : Model -> Element Msg
viewManagerForm model =
    let
        form =
            model.form

        errorMapper =
            Errors.captionFor form.problems
    in
    column [ centerX, alignTop, width (fill |> maximum 500), spacing 10 ]
        [ formPageHeader "Your Details" "(1/2)"
        , row [ spacing 10, width fill ]
            [ StyledElement.textInput [ alignTop ]
                { title = "First Name"
                , caption = Nothing
                , errorCaption =
                    errorMapper "manager_name"
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
                    errorMapper "manager_name"
                        [ EmptyLastName ]
                , value = nameString form.manager.lastName
                , onChange = Name >> UpdatedLastName
                , placeholder = Nothing
                , ariaLabel = "Last name input"
                , icon = Nothing
                }
            ]
        , el Style.captionStyle (text "Your official name")
        , spacer
        , StyledElement.emailInput [ centerX ]
            { title = "Email Address"
            , caption = Just "Your official email address"
            , errorCaption = errorMapper "manager_email" [ InvalidEmail ]
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
                errorMapper "manager_password"
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
                [ StyledElement.textLink [ Font.color Colors.darkGreen, Font.size 15 ]
                    { label = text "Login"
                    , route = Navigation.Login Nothing
                    }
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


validateManagerForm : ManagerDetailsForm -> Result (List ( Problem, String )) ValidManagerForm
validateManagerForm manager =
    let
        managerProblems =
            List.concat
                [ if isValidEmail (emailString manager.email) then
                    []

                  else
                    [ ( InvalidEmail, "There's something wrong with this email" ) ]
                , if String.isEmpty (String.trim (nameString manager.firstName)) then
                    [ ( EmptyFirstName, "Required" ) ]

                  else
                    []
                , if String.isEmpty (String.trim (nameString manager.lastName)) then
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
    in
    case managerProblems of
        [] ->
            Ok
                { name = nameString manager.firstName ++ " " ++ nameString manager.lastName
                , email = emailString manager.email
                , password = passwordString manager.password
                }

        problems ->
            Err problems


validateSchoolForm : SchoolDetailsForm -> Result (List ( Problem, String )) ValidSchoolForm
validateSchoolForm school =
    let
        schoolProblems =
            List.concat
                [ if school.schoolName == Name "" then
                    [ ( EmptySchoolName, "Required" ) ]

                  else
                    []
                , if school.perimeter == Nothing then
                    [ ( EmptySchoolLocation, "Required" ) ]

                  else
                    []
                ]
    in
    case ( schoolProblems, school.perimeter ) of
        ( [], Just location ) ->
            Ok
                { schoolLocation = location
                , schoolName = nameString school.schoolName
                }

        ( problems, _ ) ->
            Err problems


validateForm : Form -> Result (List ( Problem, String )) ValidForm
validateForm form =
    case ( validateManagerForm form.manager, validateSchoolForm form.school ) of
        ( Ok manager, Ok school ) ->
            Ok (ValidForm manager school)

        ( Err problems, _ ) ->
            Err problems

        ( _, Err problems ) ->
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
            let
                ( borderStyle, label ) =
                    if Errors.containServerErrorFor [ "manager_name", "manager_email", "manager_password" ] model.form.problems then
                        ( [ Border.color Colors.errorRed, Border.width 2 ]
                        , row [ spacing 4 ]
                            [ Icons.chevronDown [ rotate (pi / 2), Colors.fillErrorRed, alpha 1 ]
                            , text "Back"
                            ]
                        )

                    else
                        ( [], text "Back" )
            in
            row [ width fill ]
                [ if model.form.page == SchoolDetails then
                    StyledElement.button
                        ([ alignLeft, Background.color (rgba 0 0 0 0), Font.color Colors.darkText ] ++ borderStyle)
                        { label = label
                        , onPress = Just ToManagerForm
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
                                ToSchoolForm
                            )
                    }
                ]


signup : Session -> ValidForm -> Cmd Msg
signup session form =
    let
        schoolParams =
            Encode.object
                [ ( "name", Encode.string form.school.schoolName )
                , ( "geo"
                  , Encode.object
                        [ ( "lat", Encode.float form.school.schoolLocation.location.lat )
                        , ( "lng", Encode.float form.school.schoolLocation.location.lng )
                        , ( "radius", Encode.float form.school.schoolLocation.radius )
                        ]
                  )
                ]

        managerParams =
            Encode.object
                [ ( "email", Encode.string form.manager.email )
                , ( "name", Encode.string form.manager.name )
                , ( "password", Encode.string form.manager.password )
                ]

        params =
            Encode.object
                [ ( "manager", managerParams )
                , ( "school", schoolParams )
                ]
    in
    Api.post session Endpoint.signup params loginDecoder
        |> Cmd.map ReceivedSignupResponse


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.receivedMapClickLocation LocationSelected
        ]
