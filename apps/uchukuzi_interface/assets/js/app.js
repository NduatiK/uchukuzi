import { Elm } from '../src/Main.elm'
import { initializeCamera } from './camera'
import { Socket } from "phoenix"
import { ElmPhoenixChannels } from './ElmPhoenixChannels';
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
            localStorage.setItem(credentialsStorageKey, null)
            return null
        }
    }

    const credentialsStorageKey = 'credentials'
    const storedCredentials = parse(localStorage.getItem(credentialsStorageKey))


    const sideBarStateKey = "sideBarState"
    const sideBarIsOpen = parse(localStorage.getItem(sideBarStateKey))

    const windowSize = {
        width: window.innerWidth,
        height: window.innerHeight
    }


    function sleep(time) {
        return new Promise((resolve) => setTimeout(resolve, time))
    }
    app = null

    const appArgs = { credentials: storedCredentials, window: windowSize, sideBarIsOpen: sideBarIsOpen }

    console.log(appArgs)

    var app = Elm.Main.init({
        flags: appArgs,
        node: document.getElementById("elm")
    })
    new ElmPhoenixChannels(Socket, app.ports);

    setupMapPorts(app)
    app.ports.setOpenState.subscribe((state) => {
        localStorage.setItem(sideBarStateKey, state)
    })
    app.ports.printCardPort.subscribe(() => {
        printCard("")
    })
    app.ports.initializeSearchPort.subscribe(() => {
        initializeSearch(app)
    })

    app.ports.initializeCustomMap.subscribe(({ clickable, drawable }) => {
        sleep(100).then(() => {
            console.log("initializeCustomMap")
            if (drawable) {
                cleanMap()
            }
            initializeMaps(app, clickable, drawable)
        })
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

    app.ports.setSchoolLocation.subscribe((schoolLocation) => {
        localStorage.setItem(schoolLocationStorageKey,
            JSON.stringify(schoolLocation))

        window.dispatchEvent(new Event('storage'))
    })

    app.ports.storeCache.subscribe(function (credentials) {
        localStorage.setItem(credentialsStorageKey,
            JSON.stringify(credentials))
        if (credentials == null) {
            localStorage.setItem(schoolLocationStorageKey, null)
        }
        credentialsUpdated(credentials)
    })

    window.addEventListener("storage", (event) => {
        if (event.storageArea === storedCredentials && event.key === credentialsStorageKey) {
            const state = parse(event.value)
            credentialsUpdated(state)
        }
    }, false)

    function credentialsUpdated(credentials) {
        app.ports.onStoreChange.send(credentials);
    }
}

if (!env.isDevelopment) {
    var app = Elm.Main.init({
        flags: { window: windowSize, loading: true },
        node: document.getElementById("elm-loading")
    })
}


loadMapAPI()
    .then(init)
    .catch((_) => {

        if (env.isDevelopment) {
            init()
        } else {
            var app = Elm.Main.init({
                flags: { window: windowSize, error: true },
                node: document.getElementById("elm")
            })
        }
    })

