import { Elm } from "../elm/Main"
import * as Interop from "./interop";
import * as Cache from "./cache";
import * as GMaps from "./gmaps";
import { sleep } from "./sleep";

export function init() {
    var loadingApp: Elm.Main.App | null = Elm.Main.init({
        flags: loadingFlags(),
        node: document.getElementById("elm-loading")
    })

    sleep(200)
        .then(GMaps.loadMapAPI)
        .then(() => {
            loadingApp = null
            const app = createApp();
            Interop.bindPorts(app);
            GMaps.setupInterop(app)
        })
        .catch(() => {
            Elm.Main.init({
                flags: errorFlags(),
                node: document.getElementById("elm")
            })
        })
}

function createApp() {
    return Elm.Main.init({
        node: document.getElementById("elm"),
        flags: defaultFlags()
    });
}

function defaultFlags() {
    return {
        creds: Cache.getCredentials(),
        window: windowSize(),
        isLoading: false,
        sideBarIsOpen: Cache.getSidebarState(),
        hasLoadError: false
    };
}

function loadingFlags() {
    return {
        ...defaultFlags()
        , isLoading: true
    }
}
function errorFlags() {
    return {
        ...defaultFlags()
        , hasLoadError: true
    }
}

function windowSize() {
    return {
        height: window.innerHeight,
        width: window.innerWidth
    };
}
