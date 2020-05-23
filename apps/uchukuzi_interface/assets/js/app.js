import { Elm } from '../src/Main.elm'
import { initializeCamera } from './camera'
import { initializeLiveView, killLiveView } from './liveView'
import { printCard } from './card'
import env from './env'
import {
    cleanMap,
    initializeMaps,
    loadMapAPI,
    requestGeoLocation,
    initializeSearch,
    schoolLocationStorageKey,
    setupMapPorts
} from './gmaps'

const windowSize = {
    width: window.innerWidth,
    height: window.innerHeight
}

function init() {


    function parse(string) {
        try {
            return string ? JSON.parse(string) : null
        } catch (e) {
            localStorage.setItem(credentialsStorageKey, null);
            return null
        }
    }

    const credentialsStorageKey = 'credentials'
    const storedCredentials = parse(localStorage.getItem(credentialsStorageKey));

    const windowSize = {
        width: window.innerWidth,
        height: window.innerHeight
    }


    function sleep(time) {
        return new Promise((resolve) => setTimeout(resolve, time))
    }

    var app = Elm.Main.init({
        flags: { credentials: storedCredentials, window: windowSize },
        node: document.getElementById("elm")
    })

    setupMapPorts(app)

    app.ports.printCardPort.subscribe(() => {
        printCard("")
    })
    app.ports.initializeSearchPort.subscribe(() => {
        initializeSearch(app)
    })

    app.ports.initializeCustomMap.subscribe(({ clickable, drawable }) => {
        if (drawable) {
            cleanMap()
        }
        initializeMaps(app, clickable, drawable)
    })


    app.ports.requestGeoLocation.subscribe(() => {
        requestGeoLocation(app)
    })

    app.ports.setSchoolLocation.subscribe((schoolLocation) => {
        localStorage.setItem(schoolLocationStorageKey,
            JSON.stringify(schoolLocation));
    })

    app.ports.initializeCamera.subscribe(() => {
        // Give the canvas time to render
        sleep(500).then(() => {
            initializeCamera(app)
        })
    })

    app.ports.initializeLiveView.subscribe(() => {
        const { token } = parse(localStorage.getItem(credentialsStorageKey))
        if (token) {
            initializeLiveView(app, token)
        }
    })


    app.ports.storeCache.subscribe(function (credentials) {
        localStorage.setItem(credentialsStorageKey,
            JSON.stringify(credentials));
        if (credentials == null) {
            localStorage.setItem(schoolLocationStorageKey, null);
        }
        credentialsUpdated(credentials)
    });

    window.addEventListener("storage", (event) => {
        if (event.storageArea === storedCredentials && event.key === credentialsStorageKey) {
            const state = parse(event.value)
            credentialsUpdated(state)
        }
    }, false);

    function credentialsUpdated(credentials) {
        app.ports.onStoreChange.send(credentials);
        if (credentials === null) {
            killLiveView(app)
        } else {
            initializeLiveView(app)
        }
    }

}

var app = Elm.Main.init({
    flags: { window: windowSize, loading: true },
    node: document.getElementById("elm-loading")
})



loadMapAPI()
    .then(init)
    .catch((_) => {
        var app = Elm.Main.init({
            flags: { window: windowSize, error: true },
            node: document.getElementById("elm")
        })

        if (env.isDevelopment) {
            console.log("inite")
            init()
        }
    })

