module Pages.Households.HouseholdRegistrationPage exposing (Model, Msg, init, update, view)

import Api
import Api.Endpoint as Endpoint
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html.Attributes exposing (id)
import Html.Events exposing (..)
import Http
import Icons
import Json.Decode as Decode exposing (Decoder, string)
import Json.Decode.Pipeline exposing (hardcoded)
import Json.Encode as Encode
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement exposing (toDropDownView)
import Views.CustomDropDown as Dropdown
import Views.Heading exposing (viewHeading)



-- MODEL


type alias Model =
    { session : Session
    , form : Household
    , routeDropdownState : Dropdown.State String
    , searchDropdownState : Dropdown.State String
    }


type alias Household =
    { current_student_name : String
    , students : List Student
    , guardian : Guardian
    , can_track : Bool
    , home_location : Location
    , pickup_location : Location
    , route : Maybe String
    }


type alias Student =
    { name : String
    , time : TripTime
    }


type TripTime
    = TwoWay
    | Morning
    | Evening


type alias Guardian =
    { name : String
    , phone_number : String
    , email : String
    }


type alias Location =
    { longitude : Float
    , latitude : Float
    , name : String -- You are not going to display coordinates are you?
    }


type Field
    = CurrentStudentName String
    | GuardianName String
    | HomeLocation (Maybe String)
    | Email String
    | PhoneNumber String
    | Route (Maybe String)
    | CanTrack Bool
    | TripTime Student TripTime Bool


type Msg
    = Changed Field
    | DropdownMsg (Dropdown.Msg String)
    | SearchDropdownMsg (Dropdown.Msg String)
    | SaveStudentPressed
    | DeleteStudentMsg Student
    | SubmitButtonMsg
    | ServerResponse (WebData Household)


emptyForm : Session -> Model
emptyForm session =
    { session = session
    , routeDropdownState = Dropdown.init "routeDropdown"
    , searchDropdownState = Dropdown.init "searchDropdown"
    , form =
        { current_student_name = ""
        , students =
            []
        , guardian =
            { name = ""
            , phone_number = ""
            , email = ""
            }
        , can_track = True
        , home_location = { latitude = 0, longitude = 0, name = "" }
        , pickup_location = { latitude = 0, longitude = 0, name = "" }
        , route = Nothing
        }
    }


init : Session -> ( Model, Cmd msg )
init session =
    ( emptyForm session, Ports.initializeMaps () )



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
            ( model, submit model.session form )

        SaveStudentPressed ->
            let
                newStudent =
                    { name = form.current_student_name
                    , time = TwoWay
                    }

                updated_form =
                    if form.current_student_name == "" then
                        form

                    else
                        { form
                            | students = newStudent :: form.students
                            , current_student_name = ""
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

        ServerResponse _ ->
            ( model, Cmd.none )


updateField field model =
    let
        form =
            model.form
    in
    case field of
        CurrentStudentName name ->
            let
                updated_form =
                    { form | current_student_name = name }
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

        PhoneNumber phone_number ->
            let
                guardian =
                    form.guardian

                updated_form =
                    { form | guardian = { guardian | phone_number = phone_number } }
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

        HomeLocation _ ->
            -- let
            --     updated_form =
            --         { form | route = route }
            -- in
            -- ( { model | form = updated_form }, Cmd.none )
            ( model, Cmd.none )

        CanTrack checked ->
            let
                updated_form =
                    { form | can_track = checked }
            in
            ( { model | form = updated_form }, Cmd.none )

        TripTime updatedStudent toggledTime _ ->
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
        , paddingEach { edges | top = 8, left = 24, bottom = 24 }
        ]
        [ viewHeading "Register Students" (Just "From a single home")
        , google_map model
        , viewBody model
        ]


viewBody : Model -> Element Msg
viewBody model =
    Element.column
        [ width fill, spacing 40, alignTop ]
        [ viewForm model
        ]


google_map : Model -> Element Msg
google_map model =
    el
        [ width
            (fill
                |> maximum 300
            )
        , height (px 400)
        , width fill
        , Background.color Style.darkGreenColor
        , htmlAttribute (id "google-map")
        , Border.width 1
        , inFront (google_map_search model)
        ]
        none


google_map_search : Model -> Element Msg
google_map_search model =
    el [ padding 40, htmlAttribute <| Html.Attributes.style "z-index" "10" ]
        (toDropDownView <| gmapDropDown model)


viewForm : Model -> Element Msg
viewForm model =
    let
        household =
            model.form
    in
    Element.column
        [ width (fillPortion 1), spacing 26 ]
        [ el [ width (fill |> maximum 300) ] (toDropDownView <| routeDropDown model)
        , viewDivider
        , el Style.header2Style (text "Students")

        -- , viewLocationInput household.home_location
        , viewStudentsInput household.current_student_name household.students
        , viewDivider
        , el Style.header2Style
            (text "Guardian's contacts")
        , viewGuardianNameInput household.guardian.name
        , wrappedRow [ spacing 24 ]
            [ viewEmailInput household.guardian.email
            , viewPhoneInput household.guardian.phone_number
            ]
        , viewShareLocationInput model.form.can_track
        , viewButton
        ]


viewStudentsInput : String -> List Student -> Element Msg
viewStudentsInput current_student_name students =
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
                , errorCaption = Nothing
                , icon = Nothing
                , onChange = CurrentStudentName >> Changed
                , placeholder = Nothing
                , title = "Student Name"
                , value = current_student_name
                }
            , Input.button [ padding 8, alignBottom, Background.color Style.purpleColor, Border.rounded 8 ]
                { label = Icons.addWhite []
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
                            { onChange = TripTime student Morning >> Changed
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
                            { onChange = TripTime student Evening >> Changed
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


viewPhoneInput : String -> Element Msg
viewPhoneInput phone_number =
    StyledElement.textInput
        [ alignTop
        , width
            (fill
                |> maximum 300
            )
        ]
        { ariaLabel = "Guardian's Phone Number"
        , caption = Nothing
        , errorCaption = Nothing
        , icon = Just Icons.phone
        , onChange = PhoneNumber >> Changed
        , placeholder = Nothing
        , title = "Phone Number"
        , value = phone_number
        }


viewGuardianNameInput : String -> Element Msg
viewGuardianNameInput name =
    StyledElement.emailInput
        [ width
            (fill
                |> maximum 300
            )
        ]
        { ariaLabel = "Guardian's Name"
        , caption = Nothing
        , errorCaption = Nothing
        , icon = Nothing
        , onChange = GuardianName >> Changed
        , placeholder = Nothing
        , title = "Name"
        , value = name
        }


viewEmailInput : String -> Element Msg
viewEmailInput email =
    StyledElement.emailInput
        [ width
            (fill
                |> maximum 300
            )
        ]
        { ariaLabel = "Guardian's Email Address"
        , caption = Just "Used to connect the parent to the mobile app"
        , errorCaption = Nothing
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
        , dropDownMsg = DropdownMsg
        , dropdownState = model.routeDropdownState
        , errorCaption = Nothing
        , icon = Just Icons.shuttle
        , onSelect = Route >> Changed
        , options = [ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" ]
        , title = "Route"
        , toString = identity
        }


gmapDropDown : Model -> ( Element Msg, Dropdown.Config String Msg, List String )
gmapDropDown model =
    StyledElement.dropDown []
        { ariaLabel = "Search for household on the map"
        , caption = Nothing
        , dropDownMsg = SearchDropdownMsg
        , dropdownState = model.searchDropdownState
        , errorCaption = Nothing
        , icon = Just Icons.search
        , onSelect = HomeLocation >> Changed
        , options = [ "Location 1" ]
        , title = ""
        , toString = identity
        }


viewFuelTypeDropDown : Model -> Element Msg
viewFuelTypeDropDown model =
    StyledElement.toDropDownView (gmapDropDown model)


viewButton : Element Msg
viewButton =
    el (Style.labelStyle ++ [ width fill, paddingEach { edges | right = 24 } ])
        (StyledElement.button [ alignRight ]
            { onPress = Just SubmitButtonMsg
            , label = text "Submit"
            }
        )


submit : Session -> Household -> Cmd Msg
submit session household =
    let
        params =
            Encode.object
                [ ( "guardian_name", Encode.string household.guardian.name )
                , ( "phone_number", Encode.string household.guardian.phone_number )
                , ( "email", Encode.string household.guardian.email )
                , ( "route_id", Encode.string "household.route" )
                , ( "home_location", encodeLocation household.home_location )
                , ( "pickup_location", encodeLocation household.pickup_location )
                , ( "students", Encode.list encodeStudent household.students )
                ]
                |> Http.jsonBody
    in
    Api.post session Endpoint.createHousehold params (householdDecoder household)
        |> Cmd.map ServerResponse


householdDecoder : Household -> Decoder Household
householdDecoder household =
    Decode.succeed household



-- |> hardcoded household


encodeLocation location =
    Encode.object
        [ ( "latitude", Encode.float location.latitude )
        , ( "longitude", Encode.float location.longitude )
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



-- validateForm : Form -> Result (List Problem) ValidForm
-- validateForm form =
--     let
--         problems =
--             if Validator.isValidImei form.imei then
--                 []
--             else
--                 [ InvalidIMEI ]
--     in
--     case problems of
--         [] ->
--             Ok
--                 { imei = form.imei
--                 , bus_id = Maybe.map .id form.bus
--                 }
--         _ ->
--             Err problems
