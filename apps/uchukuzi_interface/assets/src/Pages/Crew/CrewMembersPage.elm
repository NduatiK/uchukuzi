module Pages.Crew.CrewMembersPage exposing (Model, Msg, init, update, view)

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
import Views.DragAndDrop exposing (draggable, droppable)



-- MODEL


type alias Model =
    { session : Session
    , height : Int
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
    = ServerResponse (WebData Data)
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


init : Session -> Int -> ( Model, Cmd Msg )
init session height =
    ( { session = session
      , height = height
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
        ServerResponse response ->
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
                ( model
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


view : Model -> Element Msg
view model =
    column
        [ width fill
        , height (px model.height)
        , spacing 40
        , paddingXY 90 70
        , inFront (viewOverlay model)
        ]
        [ viewHeading model
        , viewBody model
        ]


viewOverlay : Model -> Element Msg
viewOverlay { selectedCrewMember } =
    el
        (Style.animatesAll
            :: (if selectedCrewMember == Nothing then
                    [ alpha 0 ]

                else
                    [ alpha 1
                    , width fill
                    , height fill
                    ]
               )
        )
        (case selectedCrewMember of
            Nothing ->
                none

            Just crewMember ->
                el
                    [ width fill
                    , height fill
                    , behindContent
                        (Input.button
                            [ width fill
                            , height fill
                            , Background.color (Colors.withAlpha Colors.black 0.6)
                            , Style.blurredStyle
                            ]
                            { onPress = Just (SelectedCrewMember Nothing)
                            , label = none
                            }
                        )
                    , inFront
                        (el [ Background.color Colors.white, Border.rounded 5, Style.elevated2, centerX, centerY, width (fill |> maximum 600), Style.animatesNone ]
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
                    ]
                    none
        )


viewHeading : Model -> Element Msg
viewHeading { data, inEditingMode } =
    row [ width fill, spacing 10 ]
        (if inEditingMode then
            column []
                [ el Style.headerStyle (text "Editing Crew")
                , el Style.captionStyle (text "Drag and drop crew members to reassign them")
                ]
                :: (case data of
                        Success _ ->
                            [ StyledElement.button [ Border.width 3, Border.color Colors.purple, Background.color Colors.white, alignRight ]
                                { label =
                                    row [ spacing 8 ]
                                        [ Icons.close [ alpha 1, Colors.fillPurple ]
                                        , el [ centerY, Font.color Colors.purple ] (text "Cancel")
                                        ]
                                , onPress = Just CancelEdits
                                }
                            , StyledElement.button
                                [ alignRight ]
                                { label =
                                    row [ spacing 8 ]
                                        [ Icons.save [ alpha 1, Colors.fillWhite ]
                                        , el [ centerY ] (text "Save changes")
                                        ]
                                , onPress = Just SaveChanges
                                }
                            ]

                        Failure _ ->
                            [ StyledElement.button [ Border.width 3, Border.color Colors.purple, Background.color Colors.white, alignRight ]
                                { label =
                                    row [ spacing 8 ]
                                        [ Icons.close [ alpha 1, Colors.fillPurple ]
                                        , el [ centerY, Font.color Colors.purple ] (text "Cancel")
                                        ]
                                , onPress = Just CancelEdits
                                }
                            , StyledElement.failureButton [ alignRight ]
                                { title = "Try Again"
                                , onPress = Just SaveChanges
                                }
                            ]

                        _ ->
                            [ Icons.loading [ centerX, alignRight ] ]
                   )

         else
            [ el Style.headerStyle (text "Crew")
            , StyledElement.ghostButton [ alignRight ]
                { title = "Re-assign"
                , icon = Icons.edit
                , onPress = Just StartEditing
                }
            , StyledElement.buttonLink [ alignRight ]
                { label =
                    row [ spacing 8 ]
                        [ Icons.add [ Colors.fillWhite ]
                        , el [ centerY ] (text "Add Crew Member")
                        ]
                , route = Navigation.CrewMemberRegistration
                }
            ]
        )


viewBody : Model -> Element Msg
viewBody model =
    case model.data of
        Success data ->
            let
                editedData =
                    applyChanges model.edits.changes data
            in
            row [ height fill, width fill, spacing 40 ]
                [ Lazy.lazy3 viewBuses editedData model.edits model.inEditingMode
                , el [ width (px 60) ] none
                , el [ width (px 2), height (px (model.height // 2)), Background.color Colors.darkness ] none
                , Lazy.lazy3 viewUnassignedCrewMembers editedData model.height model.inEditingMode
                ]

        Failure _ ->
            el (centerX :: centerY :: Style.labelStyle) (paragraph [] [ text "Something went wrong, please reload the page" ])

        _ ->
            el [ width fill, height fill ] (Icons.loading [ centerX, centerY ])


viewBuses : Data -> Edits -> Bool -> Element Msg
viewBuses editedData edits inEditingMode =
    wrappedRow
        [ alignTop
        , width (fillPortion 2)
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
            , case bus.vehicleType of
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
                   , width fill
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
