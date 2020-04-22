module Pages.Households.HouseholdRegistrationPage exposing (Model, Msg, init, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Errors exposing (Errors, InputError)
import Html.Attributes exposing (id)
import Html.Events exposing (..)
import Http
import Models.Household exposing (TravelTime(..))
import Icons
import Json.Decode as Decode exposing (Decoder, string)
import Json.Decode.Pipeline exposing (hardcoded)
import Json.Encode as Encode
import Navigation exposing (..)
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement exposing (toDropDownView)
import StyledElement.DropDown as Dropdown
import Utils.Validator exposing (..)
import Views.Heading exposing (viewHeading)



-- MODEL


type alias Model =
    { session : Session
    , form : Form
    , routeDropdownState : Dropdown.State String
    , searchDropdownState : Dropdown.State Location
    }


type alias Form =
    { currentStudent : String
    , students : List Student
    , guardian : Guardian
    , canTrack : Bool
    , homeLocation : Maybe Location
    , pickupLocation : Maybe Location
    , route : Maybe String
    , problems : List (Errors Problem)
    }


type Problem
    = EmptyGuardianName
    | EmptyGuardianEmail
    | InvalidGuardianEmail
    | EmptyGuardianPhoneNumber
    | InvalidGuardianPhoneNumber
    | EmptyStudentsList
    | EmptyPickupLocation
    | EmptyHomeLocation
    | EmptyRoute


type alias ValidForm =
    { students : ( Student, List Student )
    , guardian : Guardian
    , canTrack : Bool
    , homeLocation : Location
    , pickupLocation : Location
    , route : String
    }


type alias Student =
    { name : String
    , time : TravelTime
    }





type alias Guardian =
    { name : String
    , phoneNumber : String
    , email : String
    }


type alias Location =
    { longitude : Float
    , latitude : Float
    }


type Field
    = CurrentStudentName String
    | GuardianName String
    | HomeLocation (Maybe Location)
    | Email String
    | PhoneNumber String
    | Route (Maybe String)
    | CanTrack Bool
    | TravelTime Student TravelTime Bool


type Msg
    = Changed Field
    | DropdownMsg (Dropdown.Msg String)
    | SearchDropdownMsg (Dropdown.Msg Location)
    | SaveStudentPressed
    | DeleteStudentMsg Student
    | SubmitButtonMsg
    | ServerResponse (WebData Int)


emptyForm : Session -> Model
emptyForm session =
    { session = session
    , routeDropdownState = Dropdown.init "routeDropdown"
    , searchDropdownState = Dropdown.init "searchDropdown"
    , form =
        { currentStudent = ""
        , students =
            []
        , guardian =
            { name = ""
            , phoneNumber = ""
            , email = ""
            }
        , canTrack = True
        , homeLocation = Just { latitude = 1, longitude = 2 }
        , pickupLocation = Just { latitude = 0, longitude = 0 }

        -- , homeLocation = Nothing
        -- , pickupLocation = Nothing
        , route = Nothing
        , problems = []
        }
    }


init : Session -> ( Model, Cmd msg )
init session =
    ( emptyForm session, Ports.initializeMaps False )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form
    in
    case msg of
        Changed field ->
            updateField field model

        DropdownMsg subMsg ->
            let
                ( _, config, options ) =
                    routeDropDown model

                ( state, cmd ) =
                    Dropdown.update config subMsg model.routeDropdownState options
            in
            ( { model | routeDropdownState = state }, cmd )

        SearchDropdownMsg subMsg ->
            let
                ( _, config, options ) =
                    gmapDropDown model

                ( state, cmd ) =
                    Dropdown.update config subMsg model.searchDropdownState options
            in
            ( { model | searchDropdownState = state }, cmd )

        SubmitButtonMsg ->
            case validateForm form of
                Ok validForm ->
                    ( { model | form = { form | problems = [] } }, submit model.session validForm )

                Err problems ->
                    ( { model | form = { form | problems = Errors.toClientSideErrors problems } }, Cmd.none )

        SaveStudentPressed ->
            let
                newStudent =
                    { name = form.currentStudent
                    , time = TwoWay
                    }

                updated_form =
                    if form.currentStudent == "" then
                        form

                    else
                        { form
                            | students = newStudent :: form.students
                            , currentStudent = ""
                        }
            in
            ( { model | form = updated_form }, Cmd.none )

        DeleteStudentMsg deletedStudent ->
            let
                shouldDelete student =
                    deletedStudent /= student

                updated_form =
                    { form | students = List.filter shouldDelete form.students }
            in
            ( { model | form = updated_form }, Cmd.none )

        ServerResponse response ->
            updateStatus model response


updateStatus : Model -> WebData Int -> ( Model, Cmd Msg )
updateStatus model webData =
    case webData of
        Loading ->
            ( model, Cmd.none )

        Failure error ->
            let
                ( _, error_msg ) =
                    Errors.decodeErrors error

                apiFormErrors =
                    Errors.toServerSideErrors
                        error

                form =
                    model.form

                updatedForm =
                    { form | problems = form.problems ++ apiFormErrors }
            in
            ( { model | form = updatedForm }, error_msg )

        NotAsked ->
            ( model, Cmd.none )

        Success creds ->
            ( model
            , Navigation.rerouteTo model Navigation.HouseholdList
            )


updateField field model =
    let
        form =
            model.form
    in
    case field of
        CurrentStudentName name ->
            let
                updated_form =
                    { form | currentStudent = name }
            in
            ( { model | form = updated_form }, Cmd.none )

        GuardianName name ->
            let
                guardian =
                    form.guardian

                updated_form =
                    { form | guardian = { guardian | name = name } }
            in
            ( { model | form = updated_form }, Cmd.none )

        PhoneNumber phoneNumber ->
            let
                guardian =
                    form.guardian

                updated_form =
                    { form | guardian = { guardian | phoneNumber = phoneNumber } }
            in
            ( { model | form = updated_form }, Cmd.none )

        Email email ->
            let
                guardian =
                    form.guardian

                updated_form =
                    { form | guardian = { guardian | email = email } }
            in
            ( { model | form = updated_form }, Cmd.none )

        Route route ->
            let
                updated_form =
                    { form | route = route }
            in
            ( { model | form = updated_form }, Cmd.none )

        HomeLocation homeLocation ->
            let
                updated_form =
                    { form | homeLocation = homeLocation }
            in
            ( { model | form = updated_form }, Cmd.none )

        CanTrack checked ->
            let
                updated_form =
                    { form | canTrack = checked }
            in
            ( { model | form = updated_form }, Cmd.none )

        TravelTime updatedStudent toggledTime _ ->
            let
                transformTime originalTime =
                    case ( originalTime, toggledTime ) of
                        ( Evening, Morning ) ->
                            TwoWay

                        ( Morning, Evening ) ->
                            TwoWay

                        ( Morning, Morning ) ->
                            Evening

                        ( Evening, Evening ) ->
                            Morning

                        ( TwoWay, Evening ) ->
                            Morning

                        ( TwoWay, Morning ) ->
                            Evening

                        ( _, _ ) ->
                            originalTime

                updateStudent student =
                    if updatedStudent == student then
                        { student | time = transformTime student.time }

                    else
                        student

                updated_form =
                    { form | students = List.map updateStudent form.students }
            in
            ( { model | form = updated_form }, Cmd.none )



-- VIEW


view : Model -> Element Msg
view model =
    column
        [ width fill
        , height fill
        , spacing 24
        , padding 24
        ]
        [ viewHeading "Register Household" Nothing
        , googleMap model
        , viewBody model
        ]


googleMap_search : Model -> Element Msg
googleMap_search model =
    el [ padding 40, width (fill |> maximum 400) ]
        (toDropDownView <| gmapDropDown model)


googleMap : Model -> Element Msg
googleMap model =
    let
        hasMapError =
            List.any
                (\x ->
                    case x of
                        Errors.ClientSideError y _ ->
                            y == EmptyHomeLocation || y == EmptyPickupLocation

                        _ ->
                            False
                )
                model.form.problems

        mapCaptionStyle =
            if hasMapError then
                Style.errorStyle

            else
                Style.captionLabelStyle

        mapBorderStyle =
            if hasMapError then
                [ Border.color Colors.errorRed, Border.width 2, padding 2 ]

            else
                [ Border.color Colors.white, Border.width 2, padding 2 ]
    in
    column
        [ width fill
        , spacing 8
        ]
        [ el
            [ width fill
            , height (px 400)
            , inFront (googleMap_search model)
            ]
            (StyledElement.googleMap
                ([ width fill
                 , height fill

                 --  , Background.color Colors.darkGreen
                 , Border.width 1
                 ]
                    ++ mapBorderStyle
                )
            )
        , el mapCaptionStyle (text "Click on the map to mark the home location")
        ]


viewBody : Model -> Element Msg
viewBody model =
    Element.column
        [ width fill, spacing 40, alignTop ]
        [ viewForm model
        ]


viewForm : Model -> Element Msg
viewForm model =
    let
        household =
            model.form
    in
    Element.column
        [ width (fillPortion 1), spacing 26 ]
        [ el [ width (fill |> maximum 300) ] (toDropDownView <| routeDropDown model)

        -- , viewDivider
        , el Style.header2Style (text "Students")

        -- , viewLocationInput household.home_location
        , viewStudentsInput model.form
        , viewDivider
        , el Style.header2Style
            (text "Guardian's contacts")
        , viewGuardianNameInput model.form.problems household.guardian.name
        , wrappedRow [ spacing 24 ]
            [ viewEmailInput model.form.problems household.guardian.email
            , viewPhoneInput model.form.problems household.guardian.phoneNumber
            ]

        -- , viewShareLocationInput model.form.canTrack
        , viewButton
        ]


viewStudentsInput : Form -> Element Msg
viewStudentsInput { students, problems, currentStudent } =
    let
        onEnter msg =
            Element.htmlAttribute
                (Html.Events.on "keyup"
                    (Decode.field "key" Decode.string
                        |> Decode.andThen
                            (\key ->
                                if key == "Enter" then
                                    Decode.succeed msg

                                else
                                    Decode.fail "Not the enter key"
                            )
                    )
                )

        inputFooter =
            if List.length students > 0 then
                el [ paddingEach { edges | top = 20 } ] (viewStudentsTable students)

            else
                Element.none

        errorMapper =
            Errors.inputErrorsFor problems
    in
    Element.column
        [ spacing 10
        , width fill
        ]
        [ row [ spacing 20, width fill ]
            [ StyledElement.textInput
                [ onEnter SaveStudentPressed
                , width
                    (fill
                        |> maximum 300
                    )
                ]
                { ariaLabel = "Student Name"
                , caption = Nothing
                , errorCaption = errorMapper "student" [ EmptyStudentsList ]
                , icon = Nothing
                , onChange = CurrentStudentName >> Changed
                , placeholder = Nothing
                , title = "Student Name"
                , value = currentStudent
                }
            , Input.button [ padding 8, alignBottom, Background.color Colors.purple, Border.rounded 8 ]
                { label = Icons.add [ Colors.fillWhite ]
                , onPress = Just SaveStudentPressed
                }
            ]
        , inputFooter
        ]


viewStudentsTable students =
    let
        includesMorningTrip time =
            time == Morning || time == TwoWay

        includesEveningTrip time =
            time == Evening || time == TwoWay

        tableHeader text =
            el
                Style.tableHeaderStyle
                (Element.text text)
    in
    Element.table
        [ spacing 15 ]
        { data = students
        , columns =
            [ { header = tableHeader "NAME"
              , width = fill
              , view =
                    \person ->
                        el (width (fill |> minimum 220) :: Style.tableElementStyle) (Element.text person.name)
              }
            , { header = tableHeader "MORNING"
              , width = shrink
              , view =
                    \student ->
                        Input.checkbox []
                            { onChange = TravelTime student Morning >> Changed
                            , icon = StyledElement.checkboxIcon
                            , checked = includesMorningTrip student.time
                            , label =
                                Input.labelHidden "Takes morning bus"
                            }
              }
            , { header = tableHeader "EVENING"
              , width = shrink
              , view =
                    \student ->
                        Input.checkbox []
                            { onChange = TravelTime student Evening >> Changed
                            , icon = StyledElement.checkboxIcon
                            , checked = includesEveningTrip student.time
                            , label =
                                Input.labelHidden "Takes evening bus"
                            }
              }
            , { header = tableHeader ""
              , width = shrink
              , view =
                    \student ->
                        Input.button
                            []
                            { onPress = Just (DeleteStudentMsg student)
                            , label =
                                Icons.trash
                                    [ Element.mouseOver
                                        [ alpha 0.3
                                        , Border.color (rgb 0 0.5 0)
                                        ]
                                    , Font.color (rgb 0 0.5 0)
                                    ]
                            }
              }
            ]
        }


viewLocationInput : Location -> Element Msg
viewLocationInput home =
    StyledElement.textInput
        [ width
            (fill
                |> maximum 300
            )
        ]
        { ariaLabel = "Home Location"
        , caption = Just "You can use the map to select the location"
        , errorCaption = Nothing
        , icon = Nothing
        , onChange = CurrentStudentName >> Changed
        , placeholder = Nothing
        , title = "Home Location"
        , value = "home.name"
        }


viewRouteInput : String -> Element Msg
viewRouteInput route =
    Element.column
        [ spacing 10
        , width
            (fill
                |> maximum 300
            )
        ]
        [ Input.text Style.inputStyle
            { onChange = Just >> Route >> Changed
            , text = route
            , placeholder = Nothing
            , label =
                Input.labelAbove Style.labelStyle
                    (text "Route")
            }
        ]


viewPhoneInput : List (Errors Problem) -> String -> Element Msg
viewPhoneInput problems phone_number =
    StyledElement.textInput
        [ alignTop
        , width
            (fill
                |> maximum 300
            )
        ]
        { ariaLabel = "Guardian's Phone Number"
        , caption = Nothing
        , errorCaption = Errors.inputErrorsFor problems "guardian_phone_number" [ EmptyGuardianPhoneNumber, InvalidGuardianPhoneNumber ]
        , icon = Just Icons.phone
        , onChange = PhoneNumber >> Changed
        , placeholder = Nothing
        , title = "Phone Number"
        , value = phone_number
        }


viewGuardianNameInput : List (Errors Problem) -> String -> Element Msg
viewGuardianNameInput problems name =
    StyledElement.emailInput
        [ width
            (fill
                |> maximum 300
            )
        ]
        { ariaLabel = "Guardian's Name"
        , caption = Nothing
        , errorCaption = Errors.inputErrorsFor problems "guardian_name" [ EmptyGuardianName ]
        , icon = Nothing
        , onChange = GuardianName >> Changed
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
        { ariaLabel = "Guardian's Email Address"
        , caption = Just "Used to connect the parent to the mobile app"
        , errorCaption = Errors.inputErrorsFor problems "guardian_email" [ EmptyGuardianEmail, InvalidGuardianEmail ]
        , icon = Just Icons.email
        , onChange = Email >> Changed
        , placeholder = Nothing
        , title = "Email"
        , value = email
        }


viewShareLocationInput : Bool -> Element Msg
viewShareLocationInput can_track =
    Input.checkbox []
        { onChange = CanTrack >> Changed
        , icon = StyledElement.checkboxIcon
        , checked = can_track
        , label =
            Input.labelRight Style.labelStyle
                (text "Allow parent to track vehicle?")
        }


viewDivider : Element Msg
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


routeDropDown : Model -> ( Element Msg, Dropdown.Config String Msg, List String )
routeDropDown model =
    StyledElement.dropDown []
        { ariaLabel = "Select route dropdown"
        , caption = Nothing
        , prompt = Nothing
        , dropDownMsg = DropdownMsg
        , dropdownState = model.routeDropdownState
        , errorCaption = Errors.inputErrorsFor model.form.problems "route" [ EmptyRoute ]
        , icon = Just Icons.vehicle
        , onSelect = Route >> Changed
        , options = [ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" ]
        , title = "Route"
        , toString = identity
        , isLoading = False
        }


gmapDropDown : Model -> ( Element Msg, Dropdown.Config Location Msg, List Location )
gmapDropDown model =
    StyledElement.dropDown [ Style.elevated2 ]
        { ariaLabel = "Search for household on the map"
        , caption = Nothing
        , prompt = Just "Search for area"
        , dropDownMsg = SearchDropdownMsg
        , dropdownState = model.searchDropdownState
        , errorCaption = Nothing
        , icon = Just Icons.search
        , onSelect = HomeLocation >> Changed
        , options = []
        , title = ""
        , toString = \x -> "Home"
        , isLoading = True
        }


viewButton : Element Msg
viewButton =
    el (Style.labelStyle ++ [ width fill, paddingEach { edges | right = 24 } ])
        (StyledElement.button [ alignRight ]
            { onPress = Just SubmitButtonMsg
            , label = text "Submit"
            }
        )


submit : Session -> ValidForm -> Cmd Msg
submit session household =
    let
        guardian =
            Encode.object
                [ ( "name", Encode.string household.guardian.name )
                , ( "phone_number", Encode.string household.guardian.phoneNumber )
                , ( "email", Encode.string household.guardian.email )
                ]

        params =
            Encode.object
                [ ( "guardian", guardian )
                , ( "students", Encode.list encodeStudent (Tuple.first household.students :: Tuple.second household.students) )
                , ( "route", Encode.string "household.route" )
                , ( "home_location", encodeLocation household.homeLocation )
                , ( "pickup_location", encodeLocation household.pickupLocation )
                ]
                |> Http.jsonBody
    in
    Api.post session Endpoint.households params aDecoder
        |> Cmd.map ServerResponse


aDecoder : Decoder Int
aDecoder =
    Decode.succeed 0


encodeLocation location =
    Encode.object
        [ ( "lat", Encode.float location.latitude )
        , ( "lng", Encode.float location.longitude )
        ]


encodeStudent student =
    let
        travelTime =
            case student.time of
                TwoWay ->
                    "two-way"

                Morning ->
                    "morning"

                Evening ->
                    "evening"
    in
    Encode.object
        [ ( "name", Encode.string student.name )
        , ( "travel_time", Encode.string travelTime )
        ]


validateForm : Form -> Result (List ( Problem, String )) ValidForm
validateForm form =
    let
        problems =
            List.concat
                [ if String.isEmpty (String.trim form.guardian.name) then
                    [ ( EmptyGuardianName, "Required" ) ]

                  else
                    []
                , if String.isEmpty (String.trim form.guardian.email) then
                    [ ( EmptyGuardianEmail, "Required" ) ]

                  else if not (isValidEmail form.guardian.email) then
                    [ ( InvalidGuardianEmail, "There's something wrong with this email" ) ]

                  else
                    []
                , if String.isEmpty (String.trim form.guardian.phoneNumber) then
                    [ ( EmptyGuardianPhoneNumber, "Required" ) ]

                  else if not (isValidPhoneNumber form.guardian.phoneNumber) then
                    [ ( InvalidGuardianPhoneNumber, "There's something wrong with this phone number" ) ]

                  else
                    []
                ]

        unwrapNullables =
            case ( form.pickupLocation, form.homeLocation, form.route ) of
                ( Just pickupLocation, Just homeLocation, Just route ) ->
                    Ok ( pickupLocation, homeLocation, route )

                _ ->
                    Err
                        (List.concat
                            [ if form.pickupLocation == Nothing then
                                [ ( EmptyPickupLocation, "Required" ) ]

                              else
                                []
                            , if form.homeLocation == Nothing then
                                [ ( EmptyHomeLocation, "Required" ) ]

                              else
                                []
                            , if form.route == Nothing then
                                [ ( EmptyRoute, "Required" ) ]

                              else
                                []
                            ]
                        )
    in
    case ( List.head form.students, problems, unwrapNullables ) of
        ( Just student, [], Ok ( pickupLocation, homeLocation, route ) ) ->
            Ok
                { students = ( student, List.drop 1 form.students )
                , guardian = form.guardian
                , canTrack = form.canTrack
                , homeLocation = homeLocation
                , pickupLocation = pickupLocation
                , route = route
                }

        ( firstStudent, _, nullableResult ) ->
            Err
                (problems
                    ++ (if firstStudent == Nothing then
                            [ ( EmptyStudentsList, "Provide at least one student" ) ]

                        else
                            []
                       )
                    ++ (case nullableResult of
                            Err moreProblems ->
                                moreProblems

                            _ ->
                                []
                       )
                )
