module Phoenix exposing (Model, Send, addChannel, addPush, initialize, update)

{-| A wrapper library for talking to a Phoenix backend over sockets

Reference:
The contents of this module, those in the Phoenix.\* modules and the javascript file `ElmPhoenixChannels.js`
were sourced from the internals of an online multi-player scrabble game available at:
<https://github.com/zkayser/elm_scrabble>

-}

import Dict exposing (Dict)
import Json.Encode as Encode exposing (Value)
import Phoenix.Channel as Channel exposing (Channel)
import Phoenix.Message exposing (Event(..), Message(..), PhoenixCommand(..), PhoenixData)
import Phoenix.Push as Push exposing (Push)
import Phoenix.Socket as Socket exposing (Socket)
import Task


type alias Model msg =
    { socket : Socket msg
    , channels : Dict String (Channel msg)
    , pushes : Dict String (Push msg)
    , send : PhoenixData -> Cmd msg
    }


type alias Send msg =
    PhoenixData -> Cmd msg


initialize : Socket msg -> (PhoenixData -> Cmd msg) -> Model msg
initialize socket sendFn =
    { socket = socket
    , channels = Dict.empty
    , pushes = Dict.empty
    , send = sendFn
    }


addChannel : Channel msg -> Model msg -> Model msg
addChannel channel model =
    { model | channels = Dict.insert channel.topic channel model.channels }


addPush : Push msg -> Model msg -> Model msg
addPush push model =
    { model | pushes = Dict.insert push.topic push model.pushes }


update : Message msg -> Model msg -> ( Model msg, Cmd msg )
update phoenixMessage model =
    let
        socket =
            model.socket
    in
    case phoenixMessage of
        Incoming SocketClosed ->
            ( { model | socket = Socket.close socket }, maybeTriggerCommand socket.onClose )

        Incoming (SocketErrored payload) ->
            ( { model | socket = Socket.errored socket }, triggerWithPayload socket.onError payload.payload )

        Incoming SocketOpened ->
            ( { model | socket = Socket.opened socket }, maybeTriggerCommand socket.onOpen )

        Incoming (ChannelJoined payload) ->
            case Dict.get payload.topic model.channels of
                Just channel ->
                    ( updateChannelWith Channel.joined channel.topic model
                    , triggerWithPayload channel.onJoin payload.payload
                    )

                _ ->
                    ( model, Cmd.none )

        Incoming (ChannelJoinError payload) ->
            case Dict.get payload.topic model.channels of
                Just channel ->
                    ( updateChannelWith Channel.errored channel.topic model
                    , triggerWithPayload channel.onJoinError payload.payload
                    )

                _ ->
                    ( model, Cmd.none )

        Incoming (ChannelJoinTimeout payload) ->
            case Dict.get payload.topic model.channels of
                Just channel ->
                    ( updateChannelWith Channel.timedOut channel.topic model
                    , maybeTriggerCommand channel.onJoinTimeout
                    )

                _ ->
                    ( model, Cmd.none )

        Incoming (ChannelMessageReceived payload) ->
            case Dict.get payload.topic model.channels of
                Just channel ->
                    ( model, triggerWithPayload (Dict.get payload.message channel.on) payload.payload )

                _ ->
                    ( model, Cmd.none )

        Incoming (ChannelLeft payload) ->
            case Dict.get payload.topic model.channels of
                Just channel ->
                    ( updateChannelWith Channel.closed channel.topic model
                    , triggerWithPayload channel.onLeave payload.payload
                    )

                _ ->
                    ( model, Cmd.none )

        Incoming (ChannelLeaveError payload) ->
            case Dict.get payload.topic model.channels of
                Just channel ->
                    ( updateChannelWith Channel.leaveErrored channel.topic model
                    , triggerWithPayload channel.onLeaveError payload.payload
                    )

                _ ->
                    ( model, Cmd.none )

        Incoming (PushOk payload) ->
            case Dict.get payload.topic model.pushes of
                Just push ->
                    ( model, triggerWithPayload push.onOk payload.payload )

                _ ->
                    ( model, Cmd.none )

        Incoming (PushError payload) ->
            case Dict.get payload.topic model.pushes of
                Just push ->
                    ( model, triggerWithPayload push.onError payload.payload )

                _ ->
                    ( model, Cmd.none )

        Outgoing (CreateChannel channel) ->
            ( addChannel channel model, model.send { tag = "CreateChannel", data = Channel.encode channel } )

        Outgoing (CreatePush push) ->
            ( addPush push model, model.send { tag = "CreatePush", data = Push.encode push } )

        Outgoing (CreateSocket newSocket) ->
            ( model, model.send { tag = "CreateSocket", data = Socket.encode newSocket } )

        Outgoing Disconnect ->
            ( model, model.send { tag = "Disconnect", data = Encode.null } )

        Outgoing (LeaveChannel channel) ->
            ( model, model.send { tag = "LeaveChannel", data = Channel.encode channel } )



-- COMMAND HELPERS


maybeTriggerCommand : Maybe msg -> Cmd msg
maybeTriggerCommand maybeCallback =
    case maybeCallback of
        Just msg_ ->
            Task.perform identity <| Task.succeed msg_

        Nothing ->
            Cmd.none


triggerWithPayload : Maybe (Value -> msg) -> (Value -> Cmd msg)
triggerWithPayload maybeCallback =
    maybeCallback
        |> Maybe.map (\fn -> fn >> Task.succeed >> Task.perform identity)
        |> Maybe.withDefault (\_ -> Cmd.none)



-- HELPERS


updateChannelWith : (Channel msg -> Channel msg) -> String -> Model msg -> Model msg
updateChannelWith channelFn topic model =
    { model | channels = Dict.update topic (Maybe.map channelFn) model.channels }
