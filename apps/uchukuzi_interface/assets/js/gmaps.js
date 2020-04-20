import mapStyles from './mapStyles'
import { isDevelopment } from './env'


// Prevent duplicate loads
let runningRequest = null
let initializingMapsChain = null

function initializeMaps(app, _clickable, numberOfRetries, schoolLocation) {
    if (schoolLocation) {
        defaultLocation = { center: schoolLocation, zoom: 10 }
        console.log(defaultLocation)
    }

    // Piggyback on existing request if necessary
    const scriptRequest = runningRequest ? () => { return runningRequest } : loadMapAPI

    if (isDevelopment) {
        console.log("initializeMaps")
    }
    initializingMapsChain = scriptRequest()
        .then(createMapDom)
        .then(cleanMap)
        .then(insertMap)
        .then(setupMapCallbacks(app, _clickable))
        .then(addDrawTools(app))
        .catch(() => {
            runningRequest = null
        })
        .then(() => { initializingMapsChain = null })
}

/**
 * Loads the Google Maps API script (or loads a local version)
 */
function loadMapAPI() {
    // only load if google has not loaded
    if (typeof google !== typeof undefined) {
        return sleep(300).then(() => {
            return Promise.resolve(google)
        })
    }

    runningRequest = new Promise((resolve, reject) => {
        const script = document.createElement('script')
        script.type = 'text/javascript'
        script.onload = () => { resolve(google) }
        script.onerror = reject
        document.getElementsByTagName('head')[0].appendChild(script)
        script.src = "https://maps.googleapis.com/maps/api/js?key=AIzaSyB6wUhsk2tL7ihoORGBfeqc8UCRA3XRVsw&libraries=drawing"
    })
    return runningRequest
}

let MapLibraryInstance = null
let MapDomElement = null
let defaultLocation = { center: { lat: -1.2921, lng: 36.8219 }, zoom: 10 }
function createMapDom(google) {
    runningRequest = null
    if (MapDomElement && MapLibraryInstance) {
        // Reset location
        MapLibraryInstance.panTo(new google.maps.LatLng(defaultLocation.center))
        MapLibraryInstance.setZoom(defaultLocation.zoom)
        return Promise.resolve({ dom: MapDomElement, map: MapLibraryInstance })
    }

    var mapOptions = {
        panControl: false,
        zoomControl: true,
        zoomControlOptions: {
            style: google.maps.ZoomControlStyle.SMALL,
            position: google.maps.ControlPosition.RIGHT
        },
        mapTypeControl: false,
        streetViewControl: false,
        overviewMapControl: false,
        ...defaultLocation,
        styles: mapStyles,
        // gestureHandling: 'cooperative'
    }

    const newElement = document.createElement('google-map-cached')
    MapLibraryInstance = new google.maps.Map(newElement, mapOptions)
    MapDomElement = newElement



    return Promise.resolve({ dom: MapDomElement, map: MapLibraryInstance })
}

let markers = []
let drawingManager = null
let schoolCircle = null
function cleanMap(data) {
    const { dom, map } = data
    markers.forEach((x) => {
        x.setMap(null)
    })
    markers = []

    if (schoolCircle) {
        schoolCircle.setMap(null)
    }
    return Promise.resolve(data)
}

function insertMap(data) {
    const { dom, map } = data

    var mapDiv = document.getElementById('google-map')

    if (dom.parentNode) {
        dom.parentNode.removeChild(dom)
    }
    mapDiv.prepend(dom)

    return Promise.resolve(data)
}

let hasSetup = false
let clickListener = null
const setupMapCallbacks = (app, clickable) => (data) => {
    const { dom, map } = data

    if (!hasSetup) {
        // One time actions, we don't want too many subscriptions
        const updateMarker = function (update) {
            if (isDevelopment) {
                console.log("updateMarker")
            }
            let { bus, location } = update
            let marker = markers.find((value, _indx, _list) => {
                return value.id == bus
            })

            var image = {
                url: `/images/buses/${getCardinalDirection(update.bearing)}.svg`,
                size: new google.maps.Size(90, 90),
                // origin: new google.maps.Point(0, 0),
                anchor: new google.maps.Point(45, 45),
                scaledSize: new google.maps.Size(90, 90)
            }

            // var image = {
            //     url: `/images/buses/${getCardinalDirection(update.bearing)}.png`,
            //   } 

            if (marker === undefined) {
                marker = new google.maps.Marker({
                    id: bus,
                    map: map,
                    title: "Bus"
                })
                markers.push(marker)
            }
            marker.setPosition(location)
            marker.setIcon(image)
        }

        app.ports.updateBusMap.subscribe((update) => {

            sleep(100).then(() => {

                if (initializingMapsChain) {
                    initializingMapsChain.then(() => {
                        updateMarker(update)
                    })
                } else {
                    updateMarker(update)
                }
            })
        })

        app.ports.bulkUpdateBusMap.subscribe((updates) => {
            sleep(100).then(() => {
                if (initializingMapsChain) {
                    initializingMapsChain.then(() => {
                        updates.forEach(updateMarker)
                    })
                } else {
                    updates.forEach(updateMarker)
                }
            })
        })


        // Trips Map Callbacks
        app.ports.deselectPoint.subscribe(function () {
            markers.forEach((x) => {
                x.setMap(null)
            })
            markers = []
        })
        app.ports.selectPoint.subscribe(function (gmPos) {
            markers.forEach((marker, i, a) => {
                marker.setMap(null)
            })
            markers = []

            var image = {
                url: "/images/map_bus.svg",
                size: new google.maps.Size(64, 64),
                // origin: new google.maps.Point(0, 0),
                anchor: new google.maps.Point(32, 32),
                // scaledSize: new google.maps.Size(64, 64)
            }

            var marker = new google.maps.Marker({
                position: gmPos,
                map: map,
                icon: image
            })
            map.setZoom(16)

            markers.push(marker)
            map.panTo(gmPos)
        })
    }


    if (clickable) {
        if (!google.maps.event.hasListeners(map, 'click')) {
            google.maps.event.addListener(map, 'click', function (args) {
                const pos = {
                    lat: args.latLng.lat(),
                    lng: args.latLng.lng()
                }
                // insertCircle(pos, app)
            })
        }
    } else {
        if (clickListener) {
            google.maps.event.removeListener(clickListener)
        }
    }
    hasSetup = true

    app.ports.mapReady.send(true)

    return Promise.resolve(data)
}

function getCardinalDirection(angle) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']
    return directions[Math.round(angle / 45) % 8]
}

function insertCircle(pos, app) {
    let radius = 50

    if (schoolCircle) {
        radius = schoolCircle.getRadius()
        schoolCircle.setMap(null)
    }
    getMapElement()
        .then(() => {

            schoolCircle = new google.maps.Circle({
                strokeColor: '#61A591',
                strokeOpacity: 0.8,
                strokeWeight: 2,
                fillColor: '#61A591',
                fillOpacity: 0.35,
                map: MapInstance,
                draggable: true,
                geodesic: true,
                editable: true,
                center: pos,
                radius: radius // metres
            })


            function sendSchoolCircle(schoolCircle) {
                app.ports.receivedMapClickLocation.send({
                    lat: schoolCircle.center.lat(),
                    lng: schoolCircle.center.lng(),
                    radius: schoolCircle.getRadius()
                })
            }
            if (!google.maps.event.hasListeners(schoolCircle, 'radius_changed')) {
                google.maps.event.addListener(schoolCircle, 'radius_changed', function () {
                    sendSchoolCircle(schoolCircle)
                })
                google.maps.event.addListener(schoolCircle, 'center_changed', function () {
                    sendSchoolCircle(schoolCircle)
                })
            }
            MapInstance.panTo(schoolCircle.center)
            MapInstance.setZoom(16)
            sendSchoolCircle(schoolCircle)
        })
}

let polylineListener = null
const addDrawTools = (app) => (data) => {
    const { dom, map } = data


    if (!drawingManager) {
        drawingManager = new google.maps.drawing.DrawingManager({
            drawingControl: true,
            drawingControlOptions: {
                position: google.maps.ControlPosition.TOP_CENTER,
                drawingModes: ['polyline']
            }
        })

    } else {
        drawingManager.setMap(null)
        google.maps.event.removeListener(polylineListener)
    }
    polylineListener = google.maps.event.addListener(drawingControl, 'polylinecomplete', function (polyline) {
        polylines.push(polyline);
    });

    console.log("drawingManager", drawingManager)
    drawingManager.setMap(map);


    return Promise.resolve()
}



function requestGeoLocation(app) {

    if (process.env.NODE_ENV !== 'production') {
        app.ports.receivedMapClickLocation.send({
            lat: -1.2921, lng: 36.8219, radius: 50
        })
        return
    }

    function handleLocationError(error) {
        switch (error.code) {
            case error.PERMISSION_DENIED:
                alert("Request for geolocation permissions denied.")
                break
            case error.POSITION_UNAVAILABLE:
                alert("Your location information is unavailable.")
                break
            case error.TIMEOUT:
                alert("The request to get your location timed out.")
                break
            case error.UNKNOWN_ERROR:
                alert("An unknown error occurred.")
                break
        }
    }

    const options = {
        enableHighAccuracy: true,
        timeout: 5000
    }

    const success = (data) => {
        const pos = {
            lat: data.coords.latitude,
            lng: data.coords.longitude
        }
        insertCircle(pos, app)
    }

    const failure = (error) => {
        handleLocationError(error)
        app.ports.receivedMapClickLocation.send(null)
    }

    if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(success, failure, options)
    } else {
        alert("Your browser doesn't support geolocation.")
        app.ports.receivedMapClickLocation.send(null)
    }
}





function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time))
}

export { initializeMaps, requestGeoLocation }