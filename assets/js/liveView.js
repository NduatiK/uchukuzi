import { Socket } from "phoenix"


// console.log(localStorage.getItem('credentials'))
// let { token } = JSON.parse(localStorage.getItem('credentials'))
// console.log(token)
// let socket = new Socket("/socket/manager", { params: { token: token } })

// socket.connect()

// let channel = socket.channel("school:8", {})
// channel.join()
//     .receive("ok", resp => { console.log("Joined successfully", resp) })
//     .receive("error", resp => { console.log("Unable to join", resp) })


let socket

function initializeLiveView(app) {

    let { token } = JSON.parse(localStorage.getItem('credentials'))

    if (token && !socket) {

        socket = new Socket("/socket/manager", { params: { token: token } })
        socket.connect()

        let channel = socket.channel("school:1", {})
        channel.join()
            .receive("ok", on_join(channel, app))
            .receive("error", resp => { console.log("Unable to join", resp) })
    }
}

function on_join(channel, app) {
    console.log(app)
    return (resp) => {
        console.log("Joined successfully", resp)
        channel.on("bus_moved", response => {
            console.log("Returned Greeting:", response)
            app.ports.onBusMove.send(response);
        })
    }
}

function killLiveView(app) {
    if (socket) {
        socket.disconnect()
        socket = undefined
    }
}

export {
    initializeLiveView, killLiveView
}