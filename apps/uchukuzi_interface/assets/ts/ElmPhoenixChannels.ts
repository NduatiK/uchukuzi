import { Socket, Channel } from "phoenix"

// Part of a wrapper library used to make Elm -> Phoenix communication much nicer
// 
// Reference:
//  Sourced from the internals of an online multi-player scrabble game at: https://github.com/zkayser/elm_scrabble
// 
// Look at the Elm Phoenix and Phoenix.* modules for more
// 
const TAGS = {
  CREATE_SOCKET: 'CreateSocket',
  CREATE_CHANNEL: 'CreateChannel',
  CREATE_PUSH: 'CreatePush',
  DISCONNECT: 'Disconnect',
  LEAVE_CHANNEL: 'LeaveChannel',
  SOCKET_OPENED: 'SocketOpened',
  SOCKET_CLOSED: 'SocketClosed',
  SOCKET_ERRORED: 'SocketErrored',
  CHANNEL_JOINED: 'ChannelJoined',
  CHANNEL_JOIN_ERROR: 'ChannelJoinError',
  CHANNEL_JOIN_TIMEOUT: 'ChannelJoinTimeout',
  CHANNEL_LEFT: 'ChannelLeft',
  CHANNEL_LEAVE_ERROR: 'ChannelLeaveError',
  CHANNEL_MESSAGE_RECEIVED: 'ChannelMessageReceived',
  PUSH_OK: 'PushOk',
  PUSH_ERROR: 'PushError'
};

type PhoenixData = { tag: string; data: unknown }
type FromElmCallback = {
  subscribe(callback: (data: PhoenixData) => void): void
}
type ToElmCallback = {
  send(data: { tag: string; data: unknown }): void
}

export class ElmPhoenixChannels {
  socket: Socket | null
  channels: Map<string, Channel>
  toElm: ToElmCallback
  fromElm: FromElmCallback

  constructor(ports: {
    fromPhoenix: ToElmCallback,
    toPhoenix: FromElmCallback
  }) {
    this.socket = null;
    this.channels = new Map();
    this.toElm = ports.fromPhoenix;
    this.fromElm = ports.toPhoenix;
    this.fromElm.subscribe(({ tag, data }) => {
      switch (tag) {
        case TAGS.CREATE_SOCKET:
          this.connect(data as { endpoint: any; params: any; debug: any; });
          break;
        case TAGS.CREATE_CHANNEL:
          this.channelInit(data as { topic: any; payload: any; messages: any; });
          break;
        case TAGS.CREATE_PUSH:
          this.handlePush(data as { topic: any; event: any; payload: any; })
          break;
        case TAGS.DISCONNECT:
          this.disconnectSocket();
          break;
        case TAGS.LEAVE_CHANNEL:
          this.leaveChannel(data as { topic: any; })
          break;
        default:
          console.warn(`[JS]: Received an unknown message from Elm: ${tag} with data: `, data);
      }
    });
  }

  connect(args: { endpoint: any, params: any, debug: any }) {
    const { endpoint, params, debug } = args
    if (this.socket && this.socket.isConnected()) {
      return;
    }
    let logger;
    if (debug) {
      logger = (kind: any, msg: any, data: any) => console.log(`${kind}: ${msg}`, data)
    };


    const socket = new Socket(endpoint, { params: params, logger: logger });
    socket.connect();
    socket.onOpen(() => this.toElm.send({ tag: TAGS.SOCKET_OPENED, data: {} }));
    socket.onClose(() => this.toElm.send({ tag: TAGS.SOCKET_CLOSED, data: {} }));
    socket.onError(() => this.toElm.send({ tag: TAGS.SOCKET_ERRORED, data: { payload: {}, message: TAGS.SOCKET_ERRORED } }));
    this.socket = socket;
  }

  disconnectSocket() {
    if (this.socket && this.socket.isConnected()) {
      this.socket.disconnect();
    }
  }

  channelInit({ topic, payload, messages }: { topic: any, payload: any, messages: any }) {
    let channel = this.socket?.channel(topic, payload);

    if (!channel) {
      return
    }
    channel.join()
      .receive("ok", (payload: any) => {
        this.toElm.send({ tag: TAGS.CHANNEL_JOINED, data: { payload, topic, message: TAGS.CHANNEL_JOINED } });
      })
      .receive("error", (error: any) => {
        this.toElm.send({ tag: TAGS.CHANNEL_JOIN_ERROR, data: { payload: error, topic, message: TAGS.CHANNEL_JOIN_ERROR } });
      })
      .receive("timeout", () => {
        this.toElm.send({ tag: TAGS.CHANNEL_JOIN_TIMEOUT, data: { payload: {}, topic, message: TAGS.CHANNEL_JOIN_TIMEOUT } });
      })

    messages.forEach((message: any) => {
      if (!channel) {
        return
      }
      channel.on(message, (payload: any) => {
        this.toElm.send({ tag: TAGS.CHANNEL_MESSAGE_RECEIVED, data: { payload: payload, topic, message } });
      });
    });

    this.channels.set(topic, channel);
  }

  leaveChannel({ topic }: { topic: any }) {
    const channel = this.channels.get(topic)

    if (channel) {
      channel.leave()
        .receive("ok", (payload: any) => {
          this.toElm.send({ tag: TAGS.CHANNEL_LEFT, data: { payload, topic, message: TAGS.CHANNEL_LEFT } });
          this.channels.delete(topic)
        })
        .receive("error", (error: any) => {
          this.toElm.send({ tag: TAGS.CHANNEL_LEAVE_ERROR, data: { payload: error, topic, message: TAGS.CHANNEL_LEAVE_ERROR } });
        });
    }
  }

  handlePush({ topic, event, payload }: { topic: string, event: any, payload: any }) {

    const channel = this.channels.get(topic)

    if (!channel) {
      return;
    }

    channel.push(event, payload)
      .receive("ok", (payload: unknown) => {
        this.toElm.send({ tag: TAGS.PUSH_OK, data: { payload, topic, message: TAGS.PUSH_OK } })
      })
      .receive("error", (error: any) => {
        this.toElm.send({ tag: TAGS.PUSH_ERROR, data: { payload, topic, message: TAGS.PUSH_ERROR } })
      })
  }
}