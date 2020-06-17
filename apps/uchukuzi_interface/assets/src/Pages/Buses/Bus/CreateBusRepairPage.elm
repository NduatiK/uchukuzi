module Pages.Buses.Bus.CreateBusRepairPage exposing (Model, Msg, init, update, view)

import Api
import Api.Endpoint as Endpoint
import Browser.Dom
import Colors
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Errors
import Html.Attributes exposing (id)
import Icons
import Icons.Repairs
import Json.Decode as Decode exposing (Decoder, int, list, string)
import Json.Encode as Encode
import Models.Bus exposing (Part(..), Repair, imageForPart, titleForPart)
import Navigation
import Pages.Buses.Bus.Navigation exposing (BusPage(..))
import RemoteData exposing (..)
import Session exposing (Session)
import Style
import StyledElement
import Task
import Time
import Views.DragAndDrop exposing (draggable, droppable)


type alias Model =
    { session : Session
    , bus : Int
    , repairs : List Repair
    , pickedUpItem : Maybe Draggable
    , isAboveDropOffPoint : Bool
    , index : Int
    , requestState : WebData ()
    , problems : List (Errors.Errors Problem)
    }


type Draggable
    = Part Part
    | Record Int


type alias ValidRepair =
    { id : Int
    , part : String
    , description : String
    , cost : Int
    }


type Msg
    = Submit
    | ReceivedCreateResponse (WebData ())
    | NoOp
      --------
    | StartedDragging Draggable
    | StoppedDragging
    | DropOn
    | DraggedOver
      --------
    | Delete Int
    | ChangedDescription Int String
    | ChangedCost Int String


init : Int -> Session -> ( Model, Cmd Msg )
init bus session =
    ( { session = session
      , bus = bus
      , repairs = []
      , pickedUpItem = Nothing
      , isAboveDropOffPoint = False
      , index = 0
      , problems = []
      , requestState = NotAsked
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        Submit ->
            case validateForm model.repairs of
                Ok validForm ->
                    ( { model
                        | problems = []
                        , requestState = Loading
                      }
                    , submit model.session model.bus validForm
                    )

                Err problems ->
                    ( { model | problems = Errors.toValidationErrors problems }, Cmd.none )

        StartedDragging part ->
            ( { model | pickedUpItem = Just part }, Cmd.none )

        StoppedDragging ->
            ( { model
                | pickedUpItem = Nothing
                , isAboveDropOffPoint = False
              }
            , Cmd.none
            )

        DropOn ->
            case model.pickedUpItem of
                Just (Part part) ->
                    ( { model
                        | repairs = model.repairs ++ [ Repair model.index part "" 0 (Time.millisToPosix 0) ]
                        , pickedUpItem = Nothing
                        , isAboveDropOffPoint = False
                        , index = model.index + 1
                        , problems = []
                      }
                    , Browser.Dom.getViewportOf viewRecordsID
                        |> Task.andThen (.scene >> .height >> Browser.Dom.setViewportOf viewRecordsID 0)
                        |> Task.onError (\_ -> Task.succeed ())
                        |> Task.perform (\_ -> NoOp)
                    )

                _ ->
                    ( { model | pickedUpItem = Nothing, isAboveDropOffPoint = False }
                    , Cmd.none
                    )

        DraggedOver ->
            ( { model | isAboveDropOffPoint = True }, Cmd.none )

        ChangedDescription reportID description ->
            let
                repairs =
                    List.map
                        (\report ->
                            if report.id == reportID && String.length description <= 600 then
                                { report | description = description }

                            else
                                report
                        )
                        model.repairs
            in
            ( { model | repairs = repairs }, Cmd.none )

        ChangedCost reportID cost ->
            let
                repairs =
                    List.map
                        (\report ->
                            if report.id == reportID then
                                if cost == "" then
                                    { report | cost = 0 }

                                else
                                    case String.toInt cost of
                                        Just costInt ->
                                            if costInt >= 0 then
                                                { report | cost = costInt }

                                            else
                                                report

                                        Nothing ->
                                            report

                            else
                                report
                        )
                        model.repairs
            in
            ( { model | repairs = repairs }, Cmd.none )

        Delete reportID ->
            let
                repairs =
                    List.filter
                        (\report ->
                            report.id /= reportID
                        )
                        model.repairs
            in
            ( { model | repairs = repairs }, Cmd.none )

        ReceivedCreateResponse response ->
            let
                newModel =
                    { model | requestState = response }
            in
            case response of
                Success () ->
                    ( newModel, Navigation.rerouteTo newModel (Navigation.Bus model.bus BusRepairs) )

                Failure error ->
                    let
                        apiFormError =
                            Errors.toServerSideErrors error
                    in
                    ( { newModel | problems = model.problems ++ apiFormError }, Errors.toMsg error )

                _ ->
                    ( { newModel | problems = [] }, Cmd.none )



-- VIEW


view : Model -> Int -> Element Msg
view model viewHeight =
    column
        [ paddingXY 40 10
        , width fill
        , height (px viewHeight)
        , spacing 10
        ]
        [ el Style.headerStyle (text "Create Repair Record")
        , row
            [ height (px (viewHeight - 80))
            , width fill
            ]
            [ viewRecords model
            , el [ width (fillPortion 1) ] none
            , viewVehicle model
            ]
        ]


viewRecordsID : String
viewRecordsID =
    "viewRecords"


viewRecords : Model -> Element Msg
viewRecords model =
    let
        problemAttrs =
            if List.member (Errors.toValidationError noRecordsError) model.problems then
                [ Border.solid
                , Border.color Colors.errorRed
                , below (el [ Font.color Colors.errorRed, paddingXY 0 8 ] (text (Tuple.second noRecordsError)))
                ]

            else
                []
    in
    column [ height fill, width (fillPortion 4), centerX, centerY, spacing 10 ]
        [ column
            [ htmlAttribute (id viewRecordsID)
            , htmlAttribute (Html.Attributes.style "scroll-behavior" "smooth")
            , scrollbarY
            , width fill
            , spacing 10
            ]
            (List.map (viewRecord model.problems) model.repairs)
        , el
            ([ height (px 66)
             , width fill
             , Border.dashed
             , Border.width 3
             ]
                ++ (if model.isAboveDropOffPoint && model.pickedUpItem /= Nothing then
                        [ Background.color (Colors.withAlpha Colors.darkGreen 0.3) ]

                    else
                        []
                   )
                ++ problemAttrs
                ++ droppable
                    { onDrop = DropOn
                    , onDragOver = DraggedOver
                    }
            )
            (el [ centerX, centerY ]
                (text "Drag and drop a vehicle part here ")
            )
        ]


viewRecord : List (Errors.Errors Problem) -> Repair -> Element Msg
viewRecord problems repair =
    let
        errorMapper field match =
            Errors.customInputErrorsFor
                { problems = problems
                , serverFieldName = String.fromInt repair.id ++ "_" ++ field
                , visibleName = field
                }
                match
    in
    el
        [ width fill
        , paddingXY 20 30
        , Background.color Colors.white
        , Border.width 1
        ]
        (row [ width fill ]
            [ el [ width (px 250) ]
                (imageForPart repair.part
                    ([ padding 0, alignLeft ]
                        ++ draggable
                            { onDragStart = StartedDragging (Record repair.id)
                            , onDragEnd = StoppedDragging
                            }
                    )
                )
            , column [ width fill, height fill, spacing 16 ]
                [ row [ width fill ]
                    [ el [ Font.variant Font.smallCaps, Font.medium, alignTop ] (text (titleForPart repair.part))
                    , el [ alignRight ] (StyledElement.plainButton [] { onPress = Just (Delete repair.id), label = Icons.trash [ Colors.fillErrorRed, alpha 1 ] })
                    ]
                , column [ width fill, height fill ]
                    [ el (alignRight :: Style.captionStyle)
                        (text (String.fromInt (String.length repair.description) ++ "/500"))
                    , StyledElement.multilineInput [ width fill, height fill ]
                        { ariaLabel = "Description of repair"
                        , caption = Just "Description of repair"
                        , errorCaption = errorMapper "description" []
                        , icon = Nothing
                        , onChange = ChangedDescription repair.id
                        , placeholder = Nothing
                        , title = ""
                        , value = repair.description
                        }
                    ]
                , StyledElement.textInput []
                    { ariaLabel = "Cost of repair"
                    , caption = Just "Cost of repair"
                    , errorCaption = errorMapper "cost" [ RepairProblem repair.id ZeroCost ]
                    , icon = Nothing
                    , onChange = ChangedCost repair.id
                    , placeholder = Nothing
                    , title = ""
                    , value =
                        if repair.cost == 0 then
                            ""

                        else
                            String.fromInt repair.cost
                    }
                ]
            ]
        )


viewVehicle model =
    let
        visibleParts =
            List.map .part model.repairs

        viewImage part =
            if model.pickedUpItem /= Just (Part part) && not (List.member part visibleParts) then
                inFront
                    (imageForPart part
                        (draggable
                            { onDragStart = StartedDragging (Part part)
                            , onDragEnd = StoppedDragging
                            }
                        )
                    )

            else
                moveUp 0
    in
    column
        ([ height fill, width (fillPortion 2), paddingXY 0 30 ]
            ++ droppable
                { onDrop =
                    Delete
                        (Maybe.withDefault -1
                            (case model.pickedUpItem of
                                Just (Record id) ->
                                    Just id

                                _ ->
                                    Nothing
                            )
                        )
                , onDragOver = NoOp
                }
        )
        [ el [ alignRight, centerY, width fill ]
            (Icons.Repairs.chassis
                [ centerY
                , centerX
                , inFront (Icons.Repairs.engine [])
                , viewImage VerticalAxis
                , viewImage Engine

                --
                , viewImage FrontLeftTire
                , viewImage FrontRightTire

                --
                , viewImage RearLeftTire
                , viewImage RearRightTire

                --
                , viewImage FrontCrossAxis
                , viewImage RearCrossAxis
                ]
            )
        , viewButton model.requestState
        ]


viewButton : WebData a -> Element Msg
viewButton requestState =
    let
        buttonView =
            case requestState of
                Loading ->
                    Icons.loading [ alignRight, width (px 46), height (px 46) ]

                Failure _ ->
                    StyledElement.failureButton [ alignRight ]
                        { title = "Try Again"
                        , onPress = Just Submit
                        }

                _ ->
                    StyledElement.button [ alignRight ]
                        { onPress = Just Submit
                        , label = text "Submit"
                        }
    in
    el (Style.labelStyle ++ [ width fill ])
        buttonView



-- HTTP


type Problem
    = RepairProblem Int ActualProblem
    | NoRecordsCreated


noRecordsError =
    ( NoRecordsCreated, "At least one record is required" )


type ActualProblem
    = ZeroCost


validateForm : List Repair -> Result (List ( Problem, String )) (List ValidRepair)
validateForm repairs =
    let
        problemsFor repair =
            List.concat
                [ if repair.cost == 0 then
                    [ ( RepairProblem repair.id ZeroCost, "Please provide the cost for this repair" ) ]

                  else
                    []
                ]

        generalProblems =
            if repairs == [] then
                [ noRecordsError ]

            else
                []
    in
    case List.concat (List.map problemsFor repairs) ++ generalProblems of
        [] ->
            Ok
                (List.map
                    (\x ->
                        { id = x.id
                        , part = titleForPart x.part
                        , description = x.description
                        , cost = x.cost
                        }
                    )
                    repairs
                )

        problems ->
            Err problems


submit : Session -> Int -> List ValidRepair -> Cmd Msg
submit session busID repairs =
    let
        paramsFor repair =
            Encode.object
                [ ( "id", Encode.int repair.id )
                , ( "part", Encode.string repair.part )
                , ( "cost", Encode.int repair.cost )
                , ( "description", Encode.string repair.description )
                ]

        params =
            Encode.list paramsFor repairs
    in
    Api.post session (Endpoint.performedBusRepairs busID) params decoder
        |> Cmd.map ReceivedCreateResponse


decoder : Decoder ()
decoder =
    Decode.succeed ()
