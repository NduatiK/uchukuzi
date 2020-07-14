import { Elm } from "../elm/Main"
import { Colors } from "./colors";


interface CustomWindow extends Window {
    jsQR: (imageData: any, width: number, height: number, options: { inversionAttempts: string }) => {
        data: string, location: {
            topLeftCorner: Location,
            topRightCorner: Location,
            bottomRightCorner: Location,
            bottomLeftCorner: Location
        }
    } | null;
}
declare let window: CustomWindow;

type Location = {
    x: number,
    y: number
}


let canvas: CanvasRenderingContext2D | null
let canvasElement: HTMLCanvasElement | null
let video: HTMLVideoElement | null
let freezeFrame = false
const loadQRLib = () => {
    if (typeof window.jsQR !== typeof undefined) {
        return Promise.resolve()
    }
    freezeFrame = false
    return new Promise((resolve, reject) => {
        const script = document.createElement('script')
        script.type = 'text/javascript'
        script.onload = resolve
        script.onerror = reject
        document.getElementsByTagName('head')[0].appendChild(script)
        // script.src = "https://cdn.jsdelivr.net/npm/jsqr@1.0.4/dist/jsQR.min.js"
        script.src = "/js/jsQR.min.js"

    })
}


const initializeCamera = (app: Elm.Main.App) => () => {
    sleep(500)
        .then(loadQRLib)
        .then(() => {
            app.ports.disableCamera.subscribe((after) => {
                sleep(after).then(() => { stopCamera(app) })
            })

            app.ports.setFrameFrozen.subscribe((isFrozen) => {
                setFrameFrozen(isFrozen)
            })

            const canvasEl = document.getElementById('camera-canvas')
            if (!(canvasEl instanceof HTMLCanvasElement)) {
                return
            }
            canvasElement = canvasEl
            const canvasObj = canvasElement.getContext("2d");
            if (!(canvasObj instanceof CanvasRenderingContext2D)) {
                return
            }
            canvas = canvasObj
            video = document.createElement("video");

            // Use facingMode: environment to attemt to get the front camera on phones
            navigator.mediaDevices
                .getUserMedia({ video: { facingMode: "environment" } })
                .then((stream) => {
                    if (video) {

                        video.srcObject = stream;
                        video.setAttribute("playsinline", "true"); // required to tell iOS safari we don't want fullscreen
                        video.play();
                        app.ports.receiveCameraActive.send(true)
                        sleep(20000).then(() => { stopCamera(app) })
                        requestAnimationFrame(tick);
                    }

                })
                .catch((e) => {

                    if (e.message.match("not found")) {
                        app.ports.noCameraFoundError.send(true)
                    }
                    app.ports.receiveCameraActive.send(false)
                })

            function tick() {
                if (!video) {
                    return
                }

                if (freezeFrame) {
                    sleep(0).then(() => { requestAnimationFrame(tick) });
                    return
                }

                if (video.readyState === video.HAVE_ENOUGH_DATA) {
                    if (!canvasElement || !canvas) {
                        return
                    }

                    canvasElement.height = video.videoHeight;
                    canvasElement.width = video.videoWidth;
                    canvas.drawImage(video, 0, 0, canvasElement.width, canvasElement.height);
                    var imageData = canvas.getImageData(
                        0,
                        0,
                        canvasElement.width,
                        canvasElement.height
                    );
                    const jsQR = window.jsQR
                    if (jsQR) {
                        var code = jsQR(imageData.data, imageData.width, imageData.height, { inversionAttempts: 'dontInvert' });
                        if (code && code.data !== "") {
                            drawBox(
                                code.location.topLeftCorner,
                                code.location.topRightCorner,
                                code.location.bottomRightCorner,
                                code.location.bottomLeftCorner,
                                Colors.purple
                            );
                            freezeFrame = true;
                            app.ports.scannedDeviceCode.send(code.data)
                        }
                    }
                }

                sleep(0).then(() => { requestAnimationFrame(tick) });
            }
        })
        .catch((e) => {
            app.ports.receiveCameraActive.send(false)
        })
}



function drawBox(begin: Location, b: Location, c: Location, d: Location, color: string) {
    if (!canvas) { return }
    canvas.beginPath();
    canvas.moveTo(begin.x, begin.y);
    canvas.lineTo(b.x, b.y);
    canvas.lineTo(c.x, c.y);
    canvas.lineTo(d.x, d.y);
    canvas.lineTo(begin.x, begin.y);
    canvas.lineWidth = 4;
    canvas.strokeStyle = color;
    canvas.stroke();
}

function stopCamera(app: Elm.Main.App) {
    if (!video || !canvasElement || !canvas) {
        return
    }


    var stream = video.srcObject
    if (stream instanceof MediaStream) {

        stream.getTracks().forEach(track => {
            track.stop()
        })
    }


    video.srcObject = null
    video.pause()

    app.ports.receiveCameraActive.send(false)
    canvas.clearRect(0, 0, canvasElement.width, canvasElement.height);

    canvasElement.height = 0;
    canvasElement.width = 0;

    canvas = null
    canvasElement = null
    video = null
}

function sleep(time: number) {
    return new Promise((resolve) => setTimeout(resolve, time))
}

function setFrameFrozen(isFrozen: boolean) {
    freezeFrame = isFrozen
}


export {
    initializeCamera, stopCamera, setFrameFrozen
}