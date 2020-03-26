//
// Import dependencies
//
import "phoenix"
import { Elm } from '../src/Main.elm'
import { initializeMaps } from './gmaps'
import { initializeCamera, stopCamera, setFrameFrozen } from './camera'

const storageKey = 'credentials'
const storedState = localStorage.getItem(storageKey);
const startingState = storedState ? JSON.parse(storedState) : null;

function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time))
}

var app = Elm.Main.init({
    flags: startingState,
    node: document.getElementById("elm")
})

app.ports.initializeMaps.subscribe(() => {
    let numberOfRetries = 5
    initializeMaps(app, numberOfRetries)
})

app.ports.initializeCamera.subscribe(() => {
    // Give the canvas time to render
    sleep(500).then(() => {
        initializeCamera(app)
    })
})


app.ports.storeCache.subscribe(function (credentials) {
    var credentialsJson = JSON.stringify(credentials);
    console.log(credentials)

    localStorage.setItem('credentials', credentialsJson);
});

window.addEventListener("storage", (event) => {
    if (event.storageArea === storedState && event.key === storageKey) {
        console.log("asd")
        app.ports.onStoreChange.send(event.newValue);
    }
}, false);

app.ports.received401.subscribe(function (credentials) {
    app.ports.onStoreChange.send(true);
});
