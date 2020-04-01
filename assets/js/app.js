//
// Import dependencies
//
import "phoenix"
import { Elm } from '../src/Main.elm'
import { initializeMaps, requestGeoLocation } from './gmaps'
import { initializeCamera } from './camera'

function parse(string) {
    try {
        return string ? JSON.parse(string) : null
    } catch (e) {
        localStorage.setItem(storageKey, null);
        return null
    }
}

const storageKey = 'credentials'
const storedState = localStorage.getItem(storageKey);
const startingState = parse(storedState)
const windowSize = {
    width: window.innerWidth,
    height: window.innerHeight
}


function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time))
}

var app = Elm.Main.init({
    flags: { state: startingState, window: windowSize},
    node: document.getElementById("elm")
})

app.ports.initializeMaps.subscribe((clickable) => {
    let numberOfRetries = 5
    initializeMaps(app, clickable, numberOfRetries)
})

app.ports.requestGeoLocation.subscribe(() => {
    requestGeoLocation(app)
})

app.ports.initializeCamera.subscribe(() => {
    // Give the canvas time to render
    sleep(500).then(() => {
        initializeCamera(app)
    })
})


app.ports.storeCache.subscribe(function (credentials) {
    localStorage.setItem(storageKey,
        JSON.stringify(credentials));
    app.ports.onStoreChange.send(credentials);
});

window.addEventListener("storage", (event) => {

    if (event.storageArea === storedState && event.key === storageKey) {
        const state = parse(event.value)

        app.ports.onStoreChange.send(state);
    }
}, false);