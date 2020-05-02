import mapStyles from './mapStyles'
import env from './env'
const schoolLocationStorageKey = 'schoolLocation'

const isDevelopment = env.isDevelopment

function parse(string) {
    try {
        return string ? JSON.parse(string) : null
    } catch (e) {
        localStorage.setItem(schoolLocationStorageKey, null);
        return null
    }
}
let schoolLocation = parse(localStorage.getItem(schoolLocationStorageKey));

window.addEventListener("storage", (event) => {
    if (event.storageArea === schoolLocation && event.key === schoolLocationStorageKey) {
        schoolLocation = parse(event.value)
        if (MapLibraryInstance) {
            pushSchool(MapLibraryInstance)
        }
    }
}, false);

let darkGreen = "#61A591"
let purple = "#594fee"
// Prevent duplicate loads
let runningRequest = null
let initializingMapsChain = null

let defaultLocation = { center: { lat: -1.2921, lng: 36.8219 }, zoom: 10 }

if (schoolLocation) {
    defaultLocation = { center: schoolLocation, zoom: 10 }
}

/**
 * Completely sets up the map for a page
 */
function initializeMaps(app, clickable, drawable, numberOfRetries, schoolLocation) {
    if (schoolLocation) {
        defaultLocation = { center: schoolLocation, zoom: 10 }
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
        .then(setupMapCallbacks(app, clickable))
        .then(addDrawTools(app, drawable))
    initializingMapsChain
        .catch(() => {
            runningRequest = null
        })
        .then(() => { initializingMapsChain = null })
    return initializingMapsChain
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
        script.src = "https://maps.googleapis.com/maps/api/js?key=AIzaSyB6wUhsk2tL7ihoORGBfeqc8UCRA3XRVsw&libraries=drawing,places"
    })
    return runningRequest
}

let MapLibraryInstance = null
let MapDomElement = null

/**
 * Creates a GMAPs Library Map instance and its dom element for reuse across the application
 */
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


/**
 * Removes items from the map before reuse
 */
function cleanMap(data) {
    const { dom, map } = data
    polylines.forEach((x) => {
        x.setMap(null)
    })
    polylines = []
    markers.forEach((x) => {
        x.setMap(null)
    })
    markers = []

    if (schoolCircle) {
        schoolCircle.setMap(null)
    }
    return Promise.resolve(data)
}

/**
 * Places the map within a google-map dom element
 */
function insertMap(data) {
    const { dom, map } = data

    var mapDiv = document.getElementById('google-map')

    if (dom.parentNode) {
        dom.parentNode.removeChild(dom)
    }
    mapDiv.prepend(dom)
    pushSchool(map)
    return Promise.resolve(data)
}

var schoolMarker = null

/**
 * Displaces the location of the school on the map
 */
function pushSchool(map) {
    if (!schoolLocation) {
        if (schoolMarker) {
            schoolMarker.setMap(null)
            schoolMarker = null
        }

        return
    }

    if (!schoolMarker) {
        var image = {
            url: `/images/school_marker.svg`,
            size: new google.maps.Size(26, 26),
            anchor: new google.maps.Point(13, 13),
            scaledSize: new google.maps.Size(26, 26)
        }
        schoolMarker = new google.maps.Marker({
            icon: image,
            map: map,
            title: "School"
        })
    }
    schoolMarker.setPosition(schoolLocation)

}

let hasSetup = false
let clickListener = null
const setupMapCallbacks = (app, clickable) => (data) => {
    const { dom, map } = data

    if (clickable) {
        if (!google.maps.event.hasListeners(map, 'click')) {
            clickListener = google.maps.event.addListener(map, 'click', function (args) {
                const pos = {
                    lat: args.latLng.lat(),
                    lng: args.latLng.lng()
                }
                insertCircle(pos, app, map)
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

function insertCircle(pos, app, map) {


    let radius = 50

    if (schoolCircle) {
        radius = schoolCircle.getRadius()
        schoolCircle.setMap(null)
    }

    function getMap() {
        if (map) {
            return Promise.resolve({ map: map })
        } else {
            return initializeMaps(app, true)
        }
    }

    getMap()
        .then(({ map }) => {

            schoolCircle = new google.maps.Circle({
                strokeColor: darkGreen,
                strokeOpacity: 0.8,
                strokeWeight: 2,
                fillColor: darkGreen,
                fillOpacity: 0.35,
                map: map,
                draggable: true,
                geodesic: true,
                editable: editable || false,
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

            map.panTo(schoolCircle.center)
            map.setZoom(17)
            sendSchoolCircle(schoolCircle)

        })
}

let polylineListener = null
let polylineClickListener = null
let polylines = []

const addDrawTools = (app, drawable) => (data) => {
    const { dom, map } = data

    if (drawable) {

        if (!drawingManager) {
            drawingManager = new google.maps.drawing.DrawingManager({
                drawingControl: false,
                drawingMode: google.maps.drawing.OverlayType.POLYLINE,
                polylineOptions: {
                    editable: true,
                    draggable: true,
                    strokeColor: darkGreen
                }

            })

        } else {
            drawingManager.setMap(null)
            google.maps.event.removeListener(polylineListener)
        }
        polylineListener = google.maps.event.addListener(drawingManager, 'polylinecomplete', function (polyline) {
            polylines.push(polyline)
            polyline.setEditable(true);

            drawingManager.setDrawingMode(null);

            setupClicksPolyline(polyline, app)


        })
        console.log("drawingManager", drawingManager)
        drawingManager.setMap(map)
    } else {
        if (drawingManager) {
            drawingManager.setMap(null)
        }
    }


    return Promise.resolve(data)
}

function setupClicksPolyline(line, app) {
    // Adapted from http://bl.ocks.org/knownasilya/89a32e572989f0aff1f8
    if (polylineClickListener) {
        return
    }
    const locations = line.getPath().getArray().map((v, _, _array) => {
        return {
            lat: v.lat(),
            lng: v.lng()
        }
    })

    app.ports.updatedPath.send(locations)

    polylineClickListener = google.maps.event.addListener(line, 'click', function (e) {

        var line = this;

        if (typeof e.vertex === 'number') {
            var path = line.getPath();
            path.removeAt(e.vertex);
            if (path.length < 2) {
                line.setMap(null);
                app.ports.updatedPath.send([])
                drawingManager.setDrawingMode(google.maps.drawing.OverlayType.POLYLINE);
                polylineClickListener = null
            } else {
                const locations = line.getPath().getArray().map((v, _, _array) => {
                    return {
                        lat: v.lat(),
                        lng: v.lng()
                    }
                })

                app.ports.updatedPath.send(locations)
            }

        }
    });
}


function requestGeoLocation(app) {

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
            default:
                alert("An unknown error occurred.")
        }
    }

    const options = {
        enableHighAccuracy: true,
        timeout: 5000
    }

    const success = (data) => {
        const pos = {
            lat: data.coords.latitude,
            lng: data.coords.longitude,
            radius: 50
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

let homeMarker
let subscribedToShowHomeLocation
let homeMarkerDragListener
function initializeSearch(app) {
    console.log("entered initializeSearch")
    sleep(100).then(() => {

        const setup = initializeMaps(app, false, false)
            .then(({ dom, map }) => {
                setupHomeMarker(app, map)


                if (!google.maps.event.hasListeners(map, 'click')) {
                    clickListener = google.maps.event.addListener(map, 'click', function (args) {
                        homeMarker.setPosition(args.latLng)
                        app.ports.receivedMapLocation.send({
                            lat: args.latLng.lat(),
                            lng: args.latLng.lng()
                        })
                    })
                }


                var input = document.getElementById('search-input')

                console.log("initializeSearch")
                var autocomplete = new google.maps.places.Autocomplete(input)

                autocomplete.bindTo('bounds', map)

                // Set the data fields to return when the user selects a place.
                autocomplete.setFields(
                    ['address_components', 'geometry', 'name'])
                autocomplete.addListener('place_changed', function () {

                    homeMarker.setVisible(false)
                    var place = autocomplete.getPlace()
                    if (!place.geometry) {
                        window.alert("No details available for input: '" + place.name + "'")
                        return
                    }

                    // If the place has a geometry, then present it on a map.
                    if (place.geometry.viewport) {
                        map.fitBounds(place.geometry.viewport)
                    } else {
                        map.setCenter(place.geometry.location)
                        map.setZoom(17)
                    }
                    homeMarker.setPosition(place.geometry.location)
                    homeMarker.setVisible(true)

                    app.ports.receivedMapLocation.send({
                        lat: place.geometry.location.lat(),
                        lng: place.geometry.location.lng()
                    })

                    var address = ''
                    if (place.address_components) {
                        address = [
                            (place.address_components[0] && place.address_components[0].short_name || ''),
                            (place.address_components[1] && place.address_components[1].short_name || ''),
                            (place.address_components[2] && place.address_components[2].short_name || '')
                        ].join(' ')
                    }


                    // console.log(place.name)
                    // console.log(address)
                    // // infowindowContent.children['place-name'].textContent = place.name
                    // // infowindowContent.children['place-address'].textContent = address
                    // // infowindow.open(map, marker)
                })


            })
            .catch((e) => {
                console.log(e)
                app.ports.autocompleteError.send(true)
            })


    })
}

function setupHomeMarker(app, map) {
    if (homeMarker) {
        return
    }
    var image = {
        url: "/images/home_pin.svg",
        size: new google.maps.Size(24, 24),
        anchor: new google.maps.Point(12, 24),
    }
    homeMarker = new google.maps.Marker({
        draggable: true,
        map: map,
        icon: image
    })

    homeMarkerDragListener = google.maps.event.addListener(homeMarker, 'dragend', function () {
        app.ports.receivedMapLocation.send({
            lat: homeMarker.getPosition().lat(),
            lng: homeMarker.getPosition().lng()
        })
    })
}

function setupPorts(app) {

    if (!hasSetup) {
        // One time actions, we don't want too many subscriptions
        const updateMarker = function (update) {
            initializeMaps(app, false, false)
                .then(({ dom, map }) => {
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
                        anchor: new google.maps.Point(45, 45),
                        scaledSize: new google.maps.Size(90, 90)
                    }

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

                })
        }


        app.ports.showHomeLocation.subscribe((location) => {
            initializeMaps(app, false, false)
                .then(({ dom, map }) => {
                    setupHomeMarker(app, map)

                    homeMarker.setPosition(location)

                })
        })

        app.ports.showHomeLocation.subscribe((location) => {
            initializeMaps(app, false, false)
                .then(({ dom, map }) => {
                    setupHomeMarker(app, map)
                    homeMarker.setPosition(location)
                })

        })

        app.ports.updateBusMap.subscribe((update) => {
            initializeMaps(app, false, false)
                .then(({ dom, map }) => {
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
        })

        app.ports.bulkUpdateBusMap.subscribe((updates) => {
            initializeMaps(app, false, false)
                .then(({ dom, map }) => {
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
        })

        app.ports.highlightPath.subscribe(({ routeID, highlighted }) => {
            const performHighlighting = () => {
                console.log("highlightPath")
                let polyline = polylines.find((value, _indx, _list) => {
                    return value.id == routeID
                })
                if (polyline) {
                    if (highlighted) {
                        polyline.set('strokeColor', purple);

                    } else {
                        polyline.set('strokeColor', darkGreen);

                    }
                }

            }
            if (MapLibraryInstance) {
                performHighlighting()
            } else {

                initializeMaps(app, false, false)
                    .then(performHighlighting)
            }

        })

        const drawPath = (map) => ({ routeID, path, highlighted }) => {

            if (isDevelopment) {
                console.log("drawPath")
            }

            let polyline = polylines.find((value, _indx, _list) => {
                return value.id == routeID
            })
            if (!polyline) {

                polyline = new google.maps.Polyline({
                    path: path,
                    geodesic: false,
                    strokeColor: highlighted ? purple : darkGreen,
                    id: routeID
                });
                polylines.push(polyline)
            }

            if (highlighted) {
                polyline.set('strokeColor', purple);

            } else {
                polyline.set('strokeColor', darkGreen);

            }

            polyline.setMap(map);

        }



        app.ports.bulkDrawPath.subscribe((paths) => {
            initializeMaps(app, false, false)
                .then(({ dom, map }) => {
                    sleep(100).then(() => {
                        if (initializingMapsChain) {
                            initializingMapsChain.then(({ map }) => {

                                pushSchool(map)
                                paths.forEach(drawPath(map))
                            })
                        } else {
                            pushSchool(map)
                            paths.forEach(drawPath(map))
                        }
                    })
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
            initializeMaps(app, false, false)
                .then(({ dom, map }) => {
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

                    // map.setZoom(17)

                    markers.push(marker)
                    map.panTo(gmPos)
                })
        })
    }

}

function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time))
}

export {
    initializeMaps,
    requestGeoLocation,
    initializeSearch,
    schoolLocationStorageKey,
    setupPorts,
    loadMapAPI
}