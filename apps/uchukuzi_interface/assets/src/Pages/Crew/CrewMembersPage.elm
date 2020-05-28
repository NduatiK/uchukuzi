module Pages.Crew.CrewMembersPage exposing (Model, Msg, init, tabBarItems, update, view)

import Api
import Api.Endpoint as Endpoint
import Colors
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Lazy as Lazy
import Errors
import Html exposing (Html)
import Html.Attributes exposing (id)
import Icons
import Json.Decode as Decode exposing (list)
import Json.Decode.Pipeline exposing (optional, required, resolve)
import Models.Bus exposing (Bus, busDecoder)
import Models.CrewMember exposing (Change(..), CrewMember, Role(..), applyChanges, crewDecoder, encodeChanges, roleToString)
import Navigation
import RemoteData exposing (RemoteData(..), WebData)
import Session exposing (Session)
import Style exposing (edges)
import StyledElement
import StyledElement.WebDataView as WebDataView
import Template.TabBar as TabBar exposing (TabBarItem(..))
import Views.DragAndDrop exposing (draggable, droppable)



-- MODEL


type alias Model =
    { session : Session
    , data : WebData Data
    , editedData : Data
    , edits : Edits
    , inEditingMode : Bool
    , selectedCrewMember : Maybe CrewMember
    }


type alias Edits =
    { changes : List Change
    , draggedAbove : Maybe Int
    , draggingCrewMember : Maybe CrewMember
    }


emptyEdits =
    { changes = []
    , draggedAbove = Nothing
    , draggingCrewMember = Nothing
    }


type alias Data =
    { crew : List CrewMember
    , buses : List Bus
    }


type Msg
    = ReceivedCewMembersResponse  (WebData Data)
    | StartEditing
    | CancelEdits
    | SaveChanges
      ------------
    | SelectedCrewMember (Maybe CrewMember)
    | EditCrewMember CrewMember
      ------------
    | StartedDragging CrewMember
    | StoppedDragging CrewMember
    | DroppedCrewMemberOnto Bus
    | DraggedCrewMemberAbove Int
    | DroppedCrewMemberOntoUnassigned
    | DraggedCrewMemberAboveUnassigned
      ------------
    | RegisterCrewMembers
    | NoOp


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , data = Loading
      , editedData = Data [] []
      , edits =
            emptyEdits
      , inEditingMode = False
      , selectedCrewMember = Nothing
      }
    , Cmd.batch
        [ fetchCrewMembersAndBuses session
        ]
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        data =
            case model.data of
                Success data_ ->
                    Just data_

                _ ->
                    Nothing

        edits =
            model.edits
    in
    case msg of
        NoOp ->
            ( model, Cmd.none )

        RegisterCrewMembers ->
            ( model, Navigation.rerouteTo model Navigation.CrewMemberRegistration )

        ReceivedCewMembersResponse  response ->
            let
                newModel =
                    { model | data = response }
            in
            case response of
                Failure error ->
                    let
                        ( _, error_msg ) =
                            Errors.decodeErrors error
                    in
                    ( newModel, error_msg )

                Success data_ ->
                    ( { newModel
                        | editedData = data_
                        , inEditingMode = False
                        , edits = emptyEdits
                      }
                    , Cmd.none
                    )

                _ ->
                    ( newModel, Cmd.none )

        StartEditing ->
            ( { model | inEditingMode = True }, Cmd.none )

        CancelEdits ->
            ( { model | inEditingMode = False, edits = { edits | changes = [] } }, Cmd.none )

        SaveChanges ->
            if model.edits.changes == [] then
                ( { model | inEditingMode = False }
                , Cmd.none
                )

            else
                ( { model | data = Loading }
                , updateAssignments model.session model.edits.changes model.editedData
                )

        StartedDragging crewMember ->
            ( { model | edits = { edits | draggingCrewMember = Just crewMember } }, Cmd.none )

        StoppedDragging crewMember ->
            ( { model | edits = { edits | draggedAbove = Nothing } }, Cmd.none )

        DroppedCrewMemberOnto bus ->
            let
                serverData =
                    Maybe.withDefault (Data [] []) data

                newChanges =
                    case edits.draggingCrewMember of
                        Nothing ->
                            []

                        Just crewMember ->
                            let
                                replacingMember =
                                    List.head (List.filter (\c -> c.role == crewMember.role && c.bus == Just bus.id) model.editedData.crew)
                            in
                            List.concat
                                [ [ Add crewMember.id bus.id ]
                                , case crewMember.bus of
                                    Just previousBus ->
                                        [ Remove crewMember.id previousBus ]

                                    Nothing ->
                                        []
                                , case replacingMember of
                                    Just replacingMember_ ->
                                        [ Remove replacingMember_.id bus.id ]

                                    Nothing ->
                                        []
                                ]

                allChanges =
                    newChanges ++ edits.changes

                editedData =
                    applyChanges allChanges serverData

                trimmedChanges =
                    Models.CrewMember.trimChanges serverData editedData
            in
            ( { model
                | edits = { edits | changes = trimmedChanges }
                , editedData = editedData
              }
            , Cmd.none
            )

        DraggedCrewMemberAbove bus ->
            ( { model | edits = { edits | draggedAbove = Just bus } }, Cmd.none )

        DroppedCrewMemberOntoUnassigned ->
            let
                newChanges =
                    case edits.draggingCrewMember of
                        Just crewMember ->
                            case crewMember.bus of
                                Nothing ->
                                    []

                                Just previousBus ->
                                    [ Remove crewMember.id previousBus ]

                        Nothing ->
                            []

                serverData =
                    Maybe.withDefault (Data [] []) data

                allChanges =
                    newChanges ++ edits.changes

                editedData =
                    applyChanges allChanges serverData

                trimmedChanges =
                    Models.CrewMember.trimChanges serverData editedData
            in
            ( { model
                | edits =
                    { edits
                        | changes = trimmedChanges
                    }
                , editedData = editedData
              }
            , Cmd.none
            )

        DraggedCrewMemberAboveUnassigned ->
            ( { model | edits = { edits | draggedAbove = Nothing } }, Cmd.none )

        SelectedCrewMember crewMember ->
            ( { model | selectedCrewMember = crewMember }, Cmd.none )

        EditCrewMember crewMember ->
            ( model, Navigation.rerouteTo model (Navigation.EditCrewMember crewMember.id) )



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    column
        [ width fill
        , height (px viewHeight)
        , paddingEach { edges | left = 50, right = 30, top = 30, bottom = 30 }
        , spacing 40
        , inFront (viewOverlay model)
        ]
        [ viewHeading model
        , viewBody model viewHeight
        ]


viewHeading : Model -> Element Msg
viewHeading { inEditingMode } =
    if inEditingMode then
        column []
            [ Style.iconHeader Icons.people "Editing Crew"
            , el Style.captionStyle (text "Drag and drop crew members to reassign them")
            ]

    else
        Style.iconHeader Icons.people "Bus Crew"


viewBody : Model -> Int -> Element Msg
viewBody model viewHeight =
    WebDataView.view model.data
        (\data ->
            let
                editedData =
                    applyChanges model.edits.changes data

                busList =
                    case data.buses of
                        [] ->
                            column [ centerX, spacing 20, width fill ]
                                [ paragraph [ centerX, Font.center ] [ text "You have no buses set up" ]
                                , StyledElement.ghostButtonLink [ centerX ]
                                    { title = "Add a bus"
                                    , route = Navigation.BusRegistration
                                    }
                                ]

                        _ ->
                            Lazy.lazy3 viewBuses editedData model.edits model.inEditingMode
            in
            row [ height fill, width fill, spacing 40 ]
                [ busList
                , el [ width (px 60) ] none
                , el [ width (px 2), height (px (viewHeight // 2)), Background.color Colors.darkness ] none
                , Lazy.lazy3 viewUnassignedCrewMembers editedData viewHeight model.inEditingMode
                ]
        )


viewBuses : Data -> Edits -> Bool -> Element Msg
viewBuses editedData edits inEditingMode =
    wrappedRow
        [ alignTop
        , spacing 24
        ]
        (List.map (viewBus editedData edits inEditingMode) editedData.buses)


viewBus : Data -> Edits -> Bool -> Bus -> Element Msg
viewBus editedData edits inEditingMode bus =
    let
        crew =
            List.filter (\c -> c.bus == Just bus.id) editedData.crew

        drivers =
            List.filter (\x -> x.role == Driver) crew

        assistants =
            List.filter (\x -> x.role == Assistant) crew
    in
    column
        ((if inEditingMode then
            droppable
                { onDrop = DroppedCrewMemberOnto bus
                , onDragOver = DraggedCrewMemberAbove bus.id
                }

          else
            []
         )
            ++ [ Border.width 2
               , padding 24
               , alignTop
               , alignLeft
               , spacing 24
               , height fill
               ]
        )
        [ row [ spacing 10 ]
            [ column [ spacing 8 ]
                [ el (Style.headerStyle ++ [ padding 0 ]) (text bus.numberPlate)
                , el Style.labelStyle
                    (case bus.route of
                        Just route ->
                            text route.name

                        Nothing ->
                            text "Route not assigned"
                    )
                ]
            , case Models.Bus.vehicleClassToType bus.vehicleClass of
                Models.Bus.Shuttle ->
                    Icons.shuttle [ scale 0.8 ]

                Models.Bus.Van ->
                    Icons.van [ scale 0.8 ]

                _ ->
                    Icons.bus [ scale 0.8 ]
            ]
        , viewCrew bus
            drivers
            assistants
            inEditingMode
            (\role ->
                edits.draggedAbove
                    == Just bus.id
                    && Maybe.andThen (.role >> Just) edits.draggingCrewMember
                    == Just role
            )
        ]


viewCrew bus drivers assistants inEditingMode aboveRole =
    let
        viewCrewMemberSlot role =
            row
                ([ spacing 8
                 , Border.dashed
                 , Border.color Colors.sassyGrey
                 , Border.width 2
                 , padding 12
                 , Border.rounded 3
                 , if aboveRole role then
                    Background.color (Colors.withAlpha Colors.darkGreen 0.2)
                    -- Background.color Colors.sassyGrey

                   else
                    mouseOver []
                 ]
                    ++ Style.labelStyle
                )

        viewCrewMember x =
            \provideView ->
                Input.button []
                    { onPress = Just (SelectedCrewMember (Just x))
                    , label =
                        row
                            ([ spacing 8
                             , Border.width 2
                             , padding 12
                             , Border.rounded 3
                             , Background.color (Colors.withAlpha Colors.darkGreen 0.2)
                             ]
                                ++ draggable
                                    { onDragStart = StartedDragging x
                                    , onDragEnd = StoppedDragging x
                                    }
                                ++ Style.labelStyle
                            )
                            provideView
                    }
    in
    -- wrappedRow
    row
        [ spacing 16, alignBottom ]
        [ case List.head drivers of
            Just driver ->
                viewCrewMember driver
                    [ Icons.steeringWheel [ alpha 0.54 ]
                    , text driver.name
                    ]

            Nothing ->
                viewCrewMemberSlot Driver
                    [ Icons.steeringWheel [ alpha 0.54 ]
                    , el [ centerY ] (text "Assign driver")
                    ]
        , case List.head assistants of
            Just assistant ->
                viewCrewMember assistant
                    [ Icons.people [ alpha 0.54 ]
                    , text assistant.name
                    ]

            Nothing ->
                viewCrewMemberSlot Assistant
                    [ Icons.people [ alpha 0.54 ]
                    , el [ centerY ] (text "Assign assistant")
                    ]
        ]


viewUnassignedCrewMembers : Data -> Int -> Bool -> Element Msg
viewUnassignedCrewMembers data windowHeight inEditingMode =
    let
        unassignedCrewMembers =
            List.filter (\c -> c.bus == Nothing) data.crew

        unassignedDrivers =
            List.filter (\x -> x.role == Driver) unassignedCrewMembers

        unassignedAssistants =
            List.filter (\x -> x.role == Assistant) unassignedCrewMembers

        listStyle =
            Style.header2Style
                ++ [ height fill
                   , Border.color Colors.darkGreen
                   , Border.width 2
                   , width (fillPortion 1)
                   , scrollbarY
                   , spacing 2
                   , padding 0
                   , Font.color Colors.darkGreen
                   ]

        textStyle x =
            \provideView ->
                Input.button [ width fill ]
                    { onPress = Just (SelectedCrewMember (Just x))
                    , label =
                        el
                            ((if inEditingMode then
                                draggable
                                    { onDragStart = StartedDragging x
                                    , onDragEnd = StoppedDragging x
                                    }

                              else
                                []
                             )
                                ++ [ padding 8, width fill, mouseOver highlightAttrs ]
                            )
                            provideView
                    }

        highlightAttrs =
            [ Background.color Colors.darkGreen, Font.color Colors.white ]
    in
    column
        ([ width fill, height fill, spacing 8 ]
            ++ (if inEditingMode then
                    droppable
                        { onDrop = DroppedCrewMemberOntoUnassigned
                        , onDragOver = DraggedCrewMemberAboveUnassigned
                        }

                else
                    []
               )
        )
        [ column [ width fill, height (fill |> maximum (windowHeight // 2)), alignTop ]
            [ el Style.header2Style (text "Unassigned Drivers")
            , column listStyle (List.map (\x -> textStyle x (text x.name)) unassignedDrivers)
            ]
        , column [ width fill, height (fill |> maximum (windowHeight // 2)), alignTop ]
            [ el Style.header2Style (text "Unassigned Assistants")
            , column listStyle
                (List.map (\x -> textStyle x (text x.name)) unassignedAssistants)
            ]
        ]


viewOverlay : Model -> Element Msg
viewOverlay { selectedCrewMember } =
    el
        (Style.animatesAll
            :: width fill
            :: height fill
            :: behindContent
                (Input.button
                    [ width fill
                    , height fill
                    , Background.color (Colors.withAlpha Colors.black 0.6)
                    , Style.blurredStyle
                    , if selectedCrewMember == Nothing then
                        Style.clickThrough

                      else
                        Style.nonClickThrough
                    ]
                    { onPress = Just (SelectedCrewMember Nothing)
                    , label = none
                    }
                )
            :: (if selectedCrewMember == Nothing then
                    [ alpha 0
                    , Style.clickThrough
                    ]

                else
                    [ alpha 1
                    ]
               )
        )
        (case selectedCrewMember of
            Nothing ->
                none

            Just crewMember ->
                el [ Background.color Colors.white, Border.rounded 5, Style.elevated2, centerX, centerY, width (fill |> maximum 600), Style.animatesNone ]
                    (column [ spacing 8, paddingXY 0 24, width fill ]
                        [ row [ width fill, paddingXY 8 0 ]
                            [ column [ paddingXY 20 0, spacing 8 ]
                                [ el (Style.header2Style ++ [ padding 0 ]) (text crewMember.name)
                                , el Style.captionStyle (text (roleToString crewMember.role))
                                ]
                            , StyledElement.hoverButton [ alignRight ]
                                { title = "Edit details"
                                , icon = Just Icons.edit
                                , onPress = Just (EditCrewMember crewMember)
                                }
                            ]
                        , el [ width fill, height (px 2), Background.color Colors.darkness ] none
                        , column [ paddingXY 20 20, spacing 16 ]
                            [ el Style.labelStyle (text crewMember.phoneNumber)
                            , el Style.labelStyle (text crewMember.email)
                            ]
                        ]
                    )
        )


fetchCrewMembersAndBuses : Session -> Cmd Msg
fetchCrewMembersAndBuses session =
    Api.get session Endpoint.crewMembersAndBuses dataDecoder
        |> Cmd.map ServerResponse


updateAssignments : Session -> List Change -> Data -> Cmd Msg
updateAssignments session changes editedData =
    let
        updates =
            Models.CrewMember.encodeChanges changes
    in
    Api.patch session Endpoint.crewAssignmentChanges updates (Decode.succeed editedData)
        |> Cmd.map ServerResponse


dataDecoder =
    Decode.succeed Data
        |> required "crew" (list crewDecoder)
        |> required "buses" (list busDecoder)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        []


tabBarItems { data, inEditingMode } =
    if inEditingMode then
        case data of
            Loading ->
                [ TabBar.LoadingButton
                    { title = ""
                    }
                ]

            Failure _ ->
                [ TabBar.Button
                    { title = "Cancel"
                    , icon = Icons.close
                    , onPress = CancelEdits
                    }
                , TabBar.ErrorButton
                    { title = "Try Again"
                    , icon = Icons.save
                    , onPress = SaveChanges
                    }
                ]

            _ ->
                [ TabBar.Button
                    { title = "Cancel"
                    , icon = Icons.close
                    , onPress = CancelEdits
                    }
                , TabBar.Button
                    { title = "Save changes"
                    , icon = Icons.save
                    , onPress = SaveChanges
                    }
                ]

    else
        [ TabBar.Button
            { title = "Add Crew Member"
            , icon = Icons.add
            , onPress = RegisterCrewMembers
            }
        , TabBar.Button
            { title = "Re-assign"
            , icon = Icons.edit
            , onPress = StartEditing
            }
        ]
