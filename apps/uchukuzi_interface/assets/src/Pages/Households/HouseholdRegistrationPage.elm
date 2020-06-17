module Pages.Households.HouseholdRegistrationPage exposing (Model, Msg, init, subscriptions, tabBarItems, update, view)

import Api
import Api.Endpoint as Endpoint
import Browser.Dom as Dom
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Errors exposing (Errors, InputError)
import Html.Attributes exposing (id)
import Html.Events exposing (..)
import Icons
import Json.Decode as Decode exposing (Decoder, field, float, int, list, string)
import Json.Decode.Pipeline exposing (hardcoded)
import Json.Encode as Encode
import Layout.TabBar as TabBar exposing (TabBarItem(..))
import Models.Household exposing (Guardian, Household, TravelTime(..))
import Models.Location exposing (Location)
import Models.Route exposing (Route, routeDecoder)
import Navigation
import Ports
import RemoteData exposing (..)
import Session exposing (Session)
import Set
import Style exposing (edges)
import StyledElement
import StyledElement.DropDown as Dropdown
import StyledElement.WebDataView as WebDataView
import Task
import Utils.Validator exposing (..)



-- MODEL


type alias Model =
    { session : Session
    , form : Form
    , routeDropdownState : Dropdown.State Route
    , routeRequestState : WebData (List Route)
    , requestState : WebData ()
    , editState : Maybe EditState
    , index : Int
    }


type alias Form =
    { currentStudent : String
    , students : List Student
    , guardian : Guardian
    , canTrack : Bool
    , homeLocation : Maybe Location
    , route : Maybe Int
    , searchText : String
    , problems : List (Errors Problem)
    , editingStudent : Maybe Student
    , deletedStudents : Set.Set Int
    }


type Problem
    = EmptyGuardianName
    | EmptyGuardianEmail
    | InvalidGuardianEmail
    | EmptyGuardianPhoneNumber
    | InvalidGuardianPhoneNumber
    | EmptyStudentsList
    | EmptyHomeLocation
    | EmptyRoute
    | AutocompleteFailed


type alias ValidForm =
    { students : ( Student, List Student )
    , guardian : Guardian
    , canTrack : Bool
    , homeLocation : Location
    , route : Int
    }


type alias Student =
    { id : Int
    , name : String
    , time : TravelTime
    }


isEditing : Model -> Bool
isEditing model =
    model.editState /= Nothing


type alias EditState =
    { requestState : WebData Models.Household.Household
    , guardianID : Int
    }


type Field
    = CurrentStudentName String
    | GuardianName String
    | HomeLocation (Maybe Location)
    | Email String
    | PhoneNumber String
    | Route (Maybe Int)
    | CanTrack Bool
    | TravelTime Student TravelTime Bool


emptyForm : Session -> Maybe Int -> Model
emptyForm session guardianID =
    { session = session
    , routeDropdownState = Dropdown.init "routeDropdown"
    , routeRequestState = Loading
    , form =
        { currentStudent = ""
        , students =
            []
        , guardian =
            { id = -1
            , name = ""
            , phoneNumber = ""
            , email = ""
            }
        , canTrack = True
        , homeLocation = Nothing
        , route = Nothing
        , searchText = ""
        , problems = []
        , editingStudent = Nothing
        , deletedStudents = Set.fromList []
        }
    , requestState = NotAsked
    , editState =
        guardianID |> Maybe.map (EditState Loading)
    , index = -1
    }


init : Session -> Maybe Int -> ( Model, Cmd Msg )
init session guardianID =
    ( emptyForm session guardianID
    , Cmd.batch
        [ fetchRoutes session
        , case guardianID of
            Just id_ ->
                fetchHousehold session id_

            Nothing ->
                Cmd.none
        ]
    )



-- UPDATE


type Msg
    = NoOp
    | Changed Field
    | DropdownMsg (Dropdown.Msg Route)
    | SaveStudentPressed
    | SelectedStudent (Maybe Student)
    | DeselectedStudent Student
    | UpdatedSelectedStudentName String
    | DeletedStudent Student
    | SubmitButtonPressed
    | SearchTextChanged String
    | AutocompleteError
    | ReceivedMapLocation Location
    | ReturnToRegistrationList
    | ReceivedCreateResponse (WebData ())
    | ReceivedRoutesResponse (WebData (List Route))
    | ReceivedExistingHouseholdResponse (WebData Household)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form
    in
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ReturnToRegistrationList ->
            ( model, Navigation.rerouteTo model Navigation.HouseholdList )

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

        SearchTextChanged text ->
            ( { model | form = { form | searchText = text } }, Cmd.none )

        SubmitButtonPressed ->
            case validateForm form of
                Ok validForm ->
                    ( { model | form = { form | problems = [] } }
                    , if isEditing model then
                        submitEdit model validForm

                      else
                        submitNew model.session validForm
                    )

                Err problems ->
                    ( { model | form = { form | problems = Errors.toValidationErrors problems } }, Cmd.none )

        SaveStudentPressed ->
            let
                newStudent =
                    { id = model.index
                    , name = form.currentStudent
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
            ( { model
                | form = updated_form
                , index = model.index - 1
              }
            , Cmd.none
            )

        UpdatedSelectedStudentName name ->
            let
                updated_form =
                    { form
                        | editingStudent =
                            case form.editingStudent of
                                Just student ->
                                    Just { student | name = name }

                                Nothing ->
                                    form.editingStudent
                    }
            in
            ( { model | form = updated_form }, Cmd.none )

        DeselectedStudent student ->
            let
                students =
                    List.map
                        (\x ->
                            if x.id == student.id then
                                student

                            else
                                x
                        )
                        model.form.students
            in
            ( { model | form = { form | students = students, editingStudent = Nothing } }, Cmd.none )

        SelectedStudent student ->
            let
                updated_form =
                    { form | editingStudent = student }
            in
            ( { model | form = updated_form }
            , case student of
                Just student_ ->
                    Task.attempt (always NoOp) (Dom.focus (String.fromInt student_.id ++ "-student-input"))

                Nothing ->
                    Cmd.none
            )

        DeletedStudent deletedStudent ->
            if isEditing model then
                let
                    updated_form =
                        if Set.member deletedStudent.id form.deletedStudents then
                            { form | deletedStudents = Set.remove deletedStudent.id form.deletedStudents }

                        else
                            { form | deletedStudents = Set.insert deletedStudent.id form.deletedStudents }
                in
                ( { model | form = updated_form }, Cmd.none )

            else
                let
                    shouldDelete student =
                        deletedStudent /= student

                    updated_form =
                        { form | students = List.filter shouldDelete form.students }
                in
                ( { model | form = updated_form }, Cmd.none )

        AutocompleteError ->
            let
                apiFormErrors =
                    Errors.toValidationError ( AutocompleteFailed, "Unable to load autocomplete, please refresh the page" )

                updatedForm =
                    { form | problems = apiFormErrors :: form.problems }
            in
            ( { model | form = updatedForm }, Cmd.none )

        ReceivedCreateResponse response ->
            updateStatus { model | requestState = response } response

        ReceivedMapLocation location ->
            ( { model | form = { form | homeLocation = Just location } }, Cmd.none )

        ReceivedRoutesResponse response ->
            let
                newModel =
                    { model | routeRequestState = response }
            in
            case response of
                Success routes ->
                    let
                        match =
                            case model.editState of
                                Just editState ->
                                    case editState.requestState of
                                        Success household ->
                                            List.head (List.filter (\route -> route.id == household.route) routes)

                                        _ ->
                                            Nothing

                                Nothing ->
                                    Nothing
                    in
                    case match of
                        Just route ->
                            ( newModel
                            , Cmd.batch
                                [ Task.succeed (DropdownMsg (Dropdown.selectOption route)) |> Task.perform identity
                                , prepareMap newModel
                                ]
                            )

                        _ ->
                            ( newModel
                            , Cmd.batch
                                [ prepareMap newModel
                                ]
                            )

                _ ->
                    ( newModel, Cmd.none )

        ReceivedExistingHouseholdResponse response ->
            let
                editState =
                    model.editState

                newModel =
                    { model | editState = editState |> Maybe.map (\x -> { x | requestState = response }) }
            in
            case response of
                Success household ->
                    let
                        newForm =
                            { form
                                | currentStudent = ""
                                , students =
                                    List.map
                                        (\x ->
                                            { id = x.id
                                            , name = x.name
                                            , time = x.travelTime
                                            }
                                        )
                                        household.students
                                , guardian =
                                    { id = household.guardian.id
                                    , name = household.guardian.name
                                    , phoneNumber = household.guardian.phoneNumber
                                    , email = household.guardian.email
                                    }
                                , canTrack = True
                                , homeLocation = Just household.homeLocation
                                , route = Just household.route
                                , searchText = ""
                            }
                    in
                    ( { newModel | form = newForm }
                    , Cmd.batch
                        [ prepareMap newModel
                        , case model.routeRequestState of
                            Success routes ->
                                let
                                    -- _ =
                                    match =
                                        List.head (List.filter (\route -> route.id == household.route) routes)
                                in
                                case match of
                                    Just route ->
                                        Task.succeed (DropdownMsg (Dropdown.selectOption route)) |> Task.perform identity

                                    Nothing ->
                                        Cmd.none

                            _ ->
                                Cmd.none
                        ]
                    )

                _ ->
                    ( newModel, Cmd.none )


prepareMap model =
    case model.routeRequestState of
        Success routes ->
            case model.editState |> Maybe.map .requestState of
                Just (Success household) ->
                    Cmd.batch
                        [ Ports.initializeSearch
                        , Ports.showDraggableHomeLocation household.homeLocation
                        , Ports.bulkDrawPath (List.map (\r -> { routeID = r.id, path = r.path, highlighted = r.id == household.route }) routes)
                        ]

                Nothing ->
                    Cmd.batch
                        [ Ports.initializeSearch
                        , Ports.bulkDrawPath (List.map (\r -> { routeID = r.id, path = r.path, highlighted = False }) routes)
                        ]

                _ ->
                    Cmd.none

        _ ->
            Cmd.none


updateStatus : Model -> WebData () -> ( Model, Cmd Msg )
updateStatus model webData =
    case webData of
        Loading ->
            ( model, Cmd.none )

        Failure error ->
            let
                apiFormErrors =
                    Errors.toServerSideErrors error

                form =
                    model.form

                updatedForm =
                    { form | problems = form.problems ++ apiFormErrors }
            in
            ( { model | form = updatedForm }, Errors.toMsg error )

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
            ( { model
                | form = updated_form
              }
            , Cmd.none
            )

        GuardianName name ->
            let
                guardian =
                    form.guardian

                updated_form =
                    { form | guardian = { guardian | name = name } }
            in
            ( { model
                | form = updated_form
              }
            , Cmd.none
            )

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

                cmds =
                    [ case form.route of
                        Just originalRoute ->
                            Ports.highlightPath { routeID = originalRoute, highlighted = False }

                        Nothing ->
                            Cmd.none
                    , case route of
                        Just newRoute ->
                            Ports.highlightPath { routeID = newRoute, highlighted = True }

                        Nothing ->
                            Cmd.none
                    ]
            in
            ( { model | form = updated_form }, Cmd.batch cmds )

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


view : Model -> Int -> Element Msg
view model viewHeight =
    column
        [ width fill
        , height (px viewHeight)
        , scrollbarY
        , spacing 24
        , padding 30
        ]
        [ viewHeading model
        , case model.editState of
            Just state ->
                WebDataView.view state.requestState
                    (\_ ->
                        viewFormWrapper model
                    )

            Nothing ->
                viewFormWrapper model
        ]


viewFormWrapper model =
    WebDataView.view model.routeRequestState
        (\_ ->
            column [ width fill, height fill, spacing 24 ]
                [ googleMap model
                , viewBody model
                ]
        )


viewHeading : Model -> Element Msg
viewHeading model =
    let
        title =
            if isEditing model then
                "Edit Household"

            else
                "Add a Household"
    in
    row [ width fill ]
        [ el Style.headerStyle (text title)
        ]


googleMap : Model -> Element Msg
googleMap model =
    let
        hasMapError =
            List.any
                (\x ->
                    case x of
                        Errors.ValidationError y _ ->
                            y == EmptyHomeLocation

                        _ ->
                            False
                )
                model.form.problems

        mapCaptionStyle =
            if hasMapError then
                Style.errorStyle

            else
                Style.captionStyle

        mapBorderStyle =
            if hasMapError then
                [ Border.color Colors.errorRed, Border.width 2, padding 2 ]

            else
                []
    in
    column
        [ width fill
        , spacing 8
        ]
        [ el
            [ width fill
            , height (px 400)
            , inFront
                -- googleMap_search model
                (StyledElement.textInput [ padding 10 ]
                    { ariaLabel = "search input"
                    , caption = Nothing
                    , errorCaption = Errors.captionFor model.form.problems "search" [ AutocompleteFailed ]
                    , icon = Just Icons.search
                    , onChange = SearchTextChanged
                    , placeholder = Nothing
                    , title = ""
                    , value = model.form.searchText
                    }
                )
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
        , el mapCaptionStyle (text "Click on the map or search for a location to mark the home location")
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
        [ el [ width (fill |> maximum 300) ] (Dropdown.viewFromModel model routeDropDown)

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
        , viewButton model
        ]



-- Element.column
--     [ width fill, spacing 26 ]
--     [ wrappedRow [ width fill ]
--         [ column [ spacing 26, alignTop, width fill ]
--             [ el [ width (fill |> maximum 300) ] (Dropdown.viewFromModel model routeDropDown )
--             , el Style.header2Style (text "Students")
--             , viewStudentsInput model.form
--             ]
--         , viewVerticalDivider
--         , column [ spacing 26, alignTop, width fill ]
--             [ el Style.header2Style
--                 (text "Guardian's contacts")
--             , viewGuardianNameInput model.form.problems household.guardian.name
--             , wrappedRow [ spacing 24 ]
--                 [ viewEmailInput model.form.problems household.guardian.email
--                 , viewPhoneInput model.form.problems household.guardian.phoneNumber
--                 ]
--             ]
--         ]
--     -- , viewShareLocationInput model.form.canTrack
--     , viewButton model
--     ]


viewStudentsInput : Form -> Element Msg
viewStudentsInput { students, problems, currentStudent, editingStudent, deletedStudents } =
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
                column [ spacing 16 ]
                    [ el [ paddingEach { edges | top = 20 } ] (viewStudentsTable deletedStudents editingStudent students)
                    , el Style.captionStyle (text "Double-click a student's name to edit it")
                    ]

            else
                Element.none

        errorMapper =
            Errors.captionFor problems
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

            -- , StyledElement.ghostButton [ Border.width 1 ]
            --     { title = "Add"
            --     , icon = Icons.add
            --     , onPress = Just SaveStudentPressed
            --     }
            , StyledElement.iconButton [ padding 8, centerY, Background.color Colors.purple, Border.rounded 8 ]
                { icon = Icons.add
                , iconAttrs = [ Colors.fillWhite ]
                , onPress = Just SaveStudentPressed
                }
            ]
        , inputFooter
        ]


viewStudentsTable deletedStudents editingStudent students =
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
                    \student ->
                        let
                            nameEl =
                                el
                                    ([ width (fill |> minimum 220)
                                     , Events.onClick (SelectedStudent (Just student))
                                     , pointer
                                     , if Set.member student.id deletedStudents then
                                        Font.strike

                                       else
                                        moveUp 0
                                     ]
                                        ++ Style.tableElementStyle
                                    )
                                    (Element.text student.name)
                        in
                        case editingStudent of
                            Just editingStudent_ ->
                                if student.id == editingStudent_.id then
                                    Input.text
                                        [ width (fill |> minimum 220)

                                        -- , Events.onDoubleClick (SelectedStudent (Just student))
                                        , Events.onLoseFocus (DeselectedStudent editingStudent_)
                                        , htmlAttribute (Html.Attributes.id (String.fromInt student.id ++ "-student-input"))
                                        ]
                                        { label = Input.labelHidden "Update name"
                                        , onChange = UpdatedSelectedStudentName
                                        , placeholder = Nothing
                                        , text = editingStudent_.name
                                        }

                                else
                                    nameEl

                            Nothing ->
                                nameEl
              }
            , { header = tableHeader "MORNING"
              , width = shrink
              , view =
                    \student ->
                        Input.checkbox [ centerY ]
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
                        Input.checkbox [ centerY ]
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
                            [ centerY ]
                            { onPress = Just (DeletedStudent student)
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
        , errorCaption = Errors.captionFor problems "guardian_phone_number" [ EmptyGuardianPhoneNumber, InvalidGuardianPhoneNumber ]
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
        , errorCaption = Errors.captionFor problems "guardian_name" [ EmptyGuardianName ]
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
        , errorCaption = Errors.captionFor problems "guardian_email" [ EmptyGuardianEmail, InvalidGuardianEmail ]
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


routeDropDown : Model -> ( Element Msg, Dropdown.Config Route Msg, List Route )
routeDropDown model =
    let
        routes =
            case model.routeRequestState of
                Success routes_ ->
                    routes_

                _ ->
                    []
    in
    StyledElement.dropDown []
        { ariaLabel = "Select route dropdown"
        , caption = Nothing
        , prompt = Nothing
        , dropDownMsg = DropdownMsg
        , dropdownState = model.routeDropdownState
        , errorCaption = Errors.captionFor model.form.problems "route" [ EmptyRoute ]
        , icon = Just Icons.pin
        , onSelect = Maybe.map .id >> Route >> Changed
        , options = routes
        , title = "Route"
        , toString =
            \r ->
                r.name
                    ++ (case r.bus of
                            Just bus ->
                                " (" ++ String.fromInt (bus.seats - bus.occupied) ++ " seats available)"

                            Nothing ->
                                " (No bus assigned)"
                       )
        , isLoading = False
        }


viewButton : Model -> Element Msg
viewButton model =
    none


submitNew : Session -> ValidForm -> Cmd Msg
submitNew session household =
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
                , ( "route", Encode.int household.route )
                , ( "home_location", encodeLocation household.homeLocation )
                ]
    in
    Api.post session Endpoint.households params aDecoder
        |> Cmd.map ReceivedCreateResponse


submitEdit : Model -> ValidForm -> Cmd Msg
submitEdit model household =
    let
        studentEdits =
            Encode.object
                [ ( "deletes", Encode.list Encode.int (Set.toList model.form.deletedStudents) )
                , ( "edits"
                  , Encode.list encodeStudent
                        (List.filter (\x -> not (Set.member x.id model.form.deletedStudents)) model.form.students)
                  )
                ]

        guardian =
            Encode.object
                [ ( "name", Encode.string household.guardian.name )
                , ( "phone_number", Encode.string household.guardian.phoneNumber )
                , ( "email", Encode.string household.guardian.email )
                ]

        params =
            Encode.object
                [ ( "student_edits", studentEdits )
                , ( "guardian", guardian )
                , ( "route", Encode.int household.route )
                , ( "home_location", encodeLocation household.homeLocation )
                ]
    in
    Api.patch model.session (Endpoint.household model.form.guardian.id) params aDecoder
        |> Cmd.map ReceivedCreateResponse


aDecoder : Decoder ()
aDecoder =
    Decode.succeed ()


encodeLocation : Location -> Encode.Value
encodeLocation location =
    Encode.object
        [ ( "lat", Encode.float location.lat )
        , ( "lng", Encode.float location.lng )
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
        [ ( "id", Encode.int student.id )
        , ( "name", Encode.string student.name )
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
            case ( form.homeLocation, form.route ) of
                ( Just homeLocation, Just route ) ->
                    Ok ( homeLocation, route )

                _ ->
                    Err
                        (List.concat
                            [ if form.homeLocation == Nothing then
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
        ( Just student, [], Ok ( homeLocation, route ) ) ->
            Ok
                { students = ( student, List.drop 1 form.students )
                , guardian = form.guardian
                , canTrack = form.canTrack
                , homeLocation = homeLocation
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


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.autocompleteError (always AutocompleteError)
        , Ports.receivedMapLocation ReceivedMapLocation
        ]


fetchRoutes : Session -> Cmd Msg
fetchRoutes session =
    Api.get session Endpoint.routes (list routeDecoder)
        |> Cmd.map ReceivedRoutesResponse


fetchHousehold : Session -> Int -> Cmd Msg
fetchHousehold session id =
    Api.get session (Endpoint.household id) Models.Household.householdDecoder
        |> Cmd.map ReceivedExistingHouseholdResponse


tabBarItems { requestState } =
    case requestState of
        Failure _ ->
            [ TabBar.Button
                { title = "Cancel"
                , icon = Icons.close
                , onPress = ReturnToRegistrationList
                }
            , TabBar.ErrorButton
                { title = "Try Again"
                , icon = Icons.save
                , onPress = SubmitButtonPressed
                }
            ]

        Loading ->
            [ TabBar.LoadingButton
            ]

        _ ->
            [ TabBar.Button
                { title = "Cancel"
                , icon = Icons.close
                , onPress = ReturnToRegistrationList
                }
            , TabBar.Button
                { title = "Save"
                , icon = Icons.save
                , onPress = SubmitButtonPressed
                }
            ]
