import { Elm } from "../elm/Main"
import * as Interop from "./interop";
import * as Cache from "./cache";
import * as GMaps from "./gmaps";
import { sleep } from "./sleep";

export function init() {
    var loadingApp: Elm.Main.App | null = Elm.Main.init({
        flags: {
            creds: null,
            window: windowSize(),
            isLoading: true,
            sideBarIsOpen: true,
            hasLoadError: false
        },
        node: document.getElementById("elm-loading")
    })
    sleep(200).then(
        GMaps.loadMapAPI
    )
        .then(() => {
            loadingApp = null
            const app = createApp();
            Interop.bindPorts(app);
            GMaps.setupInterop(app)
        })
        .catch(() => {
            Elm.Main.init({
                flags: {
                    creds: null,
                    window: windowSize(),
                    isLoading: false,
                    sideBarIsOpen: Cache.getSidebarState(),
                    hasLoadError: true
                },
                node: document.getElementById("elm")
            })
        })
}

function createApp() {
    console.log(Cache.getSidebarState())
    return Elm.Main.init({
        node: document.getElementById("elm"),
        flags: {
            creds: Cache.getCredentials(),
            window: windowSize(),
            isLoading: false,
            sideBarIsOpen: Cache.getSidebarState(),
            hasLoadError: false
        }
    });
}

function windowSize() {
    return {
        height: window.innerHeight,
        width: window.innerWidth
    };
}
