let canvas
let canvasElement
let video
let freezeFrame = false
const loadQRLib = () => {
    if (typeof QrCode !== typeof undefined) {
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


function initializeCamera(app) {

    loadQRLib()
        .then(() => {
            app.ports.disableCamera.subscribe((after) => {
                sleep(after).then(() => { stopCamera(app) })
            })

            app.ports.setFrameFrozen.subscribe((isFrozen) => {
                setFrameFrozen(isFrozen)
            })

            video = document.createElement("video");
            canvasElement = document.getElementById('camera-canvas')
            canvas = canvasElement.getContext("2d");

            // Use facingMode: environment to attemt to get the front camera on phones
            navigator.mediaDevices
                .getUserMedia({ video: { facingMode: "environment" } })
                .then((stream) => {
                    video.srcObject = stream;
                    video.setAttribute("playsinline", true); // required to tell iOS safari we don't want fullscreen
                    video.play();
                    app.ports.receiveCameraActive.send(true)
                    sleep(20000).then(() => { stopCamera(app) })
                    requestAnimationFrame(tick);

                })
                .catch((e) => {
                    console.log(e)

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

                    canvasElement.height = video.videoHeight;
                    canvasElement.width = video.videoWidth;
                    canvas.drawImage(video, 0, 0, canvasElement.width, canvasElement.height);
                    var imageData = canvas.getImageData(
                        0,
                        0,
                        canvasElement.width,
                        canvasElement.height
                    );
                    var code = jsQR(imageData.data, imageData.width, imageData.height, { inversionAttempts: 'dontInvert' });
                    if (code) {
                        drawBox(
                            code.location.topLeftCorner,
                            code.location.topRightCorner,
                            code.location.bottomRightCorner,
                            code.location.bottomLeftCorner,
                            "#594FEE"
                        );
                        freezeFrame = true;
                        app.ports.scannedDeviceCode.send(code.data)
                    }
                }

                sleep(0).then(() => { requestAnimationFrame(tick) });
            }
        })
        .catch((e) => {
            console.log(e)
            app.ports.receiveCameraActive.send(false)
        })
}

function drawBox(begin, b, c, d, color) {
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

function stopCamera(app) {
    if (!video) {
        return
    }

    var stream = video.srcObject
    stream.getTracks().forEach(track => {
        track.stop()
    })

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

function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time))
}

function setFrameFrozen(isFrozen) {
    freezeFrame = isFrozen
}
export {
    initializeCamera, stopCamera, setFrameFrozen
}