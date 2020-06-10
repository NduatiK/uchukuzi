import mapStyles from "./mapStyles"
import env from "./env"
const schoolLocationStorageKey = "schoolLocation"

const isDevelopment = env.isDevelopment

function parse(string) {
    try {
        return string ? JSON.parse(string) : null
    } catch (e) {
        localStorage.setItem(schoolLocationStorageKey, null)
        return null
    }
}
let schoolLocation = parse(localStorage.getItem(schoolLocationStorageKey))

window.addEventListener("storage", (event) => {

    const location = parse(window.localStorage.getItem(schoolLocationStorageKey))

    if (MapLibraryInstance && schoolLocation !== location) {
        schoolLocation = location
        pushSchoolOnto(MapLibraryInstance)
    }
}, false)

let darkGreen = "#61A591"
let purple = "#594fee"
let errorRed = "#ff0000"
// Prevent duplicate loads
let runningRequest = null
let initializingMapsChain = null

let defaultLocation = { center: { lat: -1.2921, lng: 36.8219 }, zoom: 16 }

if (schoolLocation) {
    defaultLocation = { center: schoolLocation, zoom: 16 }
}

var editable = true

/**
 * Completely sets up the map for a page
 */
function initializeMaps(app, clickable = false, drawable = false, sleepTime = 800) {
    editable = clickable || drawable
    if (schoolLocation) {
        const credentialsStorageKey = "credentials"
        const storedCredentials = parse(localStorage.getItem(credentialsStorageKey))
        if (storedCredentials) {
            defaultLocation = { center: schoolLocation, zoom: 16 }
        }
    }

    initializingMapsChain = createMapDom()
        .then(insertMap(sleepTime))
        .then(setupMapCallbacks(app, clickable))
        .then(addDrawTools(app, drawable))

    return initializingMapsChain
}

/**
 * Loads the Google Maps API script (or loads a local version)
 */
function loadMapAPI() {
    // only load if google has not loaded
    if (typeof google !== typeof undefined) {
        return Promise.resolve(google)
    }

    runningRequest = new Promise((resolve, reject) => {
        const script = document.createElement("script")
        script.type = "text/javascript"
        script.onload = () => { resolve(google) }
        script.onerror = reject
        document.getElementsByTagName("head")[0].appendChild(script)
        script.src = "https://maps.googleapis.com/maps/api/js?key=AIzaSyB6wUhsk2tL7ihoORGBfeqc8UCRA3XRVsw&libraries=drawing,places"
    })
    return runningRequest
}

let MapLibraryInstance = null
let MapDomElement = null

/**
 * Creates a GMAPs Library Map instance and its dom element for reuse across the application
 */
function createMapDom() {
    runningRequest = null
    if (MapDomElement && MapLibraryInstance) {
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
        clickableIcons: false,
        overviewMapControl: false,
        ...defaultLocation,
        styles: mapStyles,
        // gestureHandling: "cooperative"
    }

    const newElement = document.createElement("google-map-cached")
    MapLibraryInstance = new google.maps.Map(newElement, mapOptions)
    MapDomElement = newElement

    return Promise.resolve({ dom: MapDomElement, map: MapLibraryInstance })
}

let markers = []
let tiles = []
let drawingManager = null
let schoolCircle = null

/**
 * Places the map within a google-map dom element
 */
const insertMap = (sleepTime) => (data) => {
    return sleep(sleepTime).then(() => {
        const { dom, map } = data

        var mapDiv = document.getElementById("google-map")

        if (dom.parentNode) {
            dom.parentNode.removeChild(dom)
        }
        mapDiv.prepend(dom)
        pushSchoolOnto(map)
        return Promise.resolve(map)
    })
}

/**
 * Removes items from the map before reuse
 */
function cleanMap() {
    console.log("cleanMap")
    polylines.forEach((x) => {
        x.setMap(null)
    })
    polylines = []

    polylineMarkers.forEach((x) => {
        x.setMap(null)
    })
    polylineMarkers = []

    if (homeMarker) {
        homeMarker.setMap(null)
        homeMarker = null
    }
    markers.forEach((x) => {
        x.setMap(null)
    })
    markers = []

    tiles.forEach((x) => {
        x.setMap(null)
    })
    tiles = []

    if (schoolCircle) {
        schoolCircle.setMap(null)
    }

    disableClickListeners(0)

    // Reset location
    if (MapLibraryInstance) {
        const map = MapLibraryInstance
        map.panTo(new google.maps.LatLng(defaultLocation.center))
        map.setZoom(defaultLocation.zoom)

        pushSchoolOnto(map)
    }
}


function cleanGrid() {
    tiles.forEach((x) => {
        x.setMap(null)
    })
    tiles = []
}

function disableClickListeners(time = 300) {
    console.log(time)
    sleep(time).then(() => {
        console.log(time)
        if (MapLibraryInstance) {
            google.maps.event.clearInstanceListeners(MapLibraryInstance, "click")
            homeMarkerMapClickListener = null
            circleClickListener = null
            mapClickListener = null
        }
    })
}

var schoolMarker = null

/**
 * Displaces the location of the school on the map
 */
function pushSchoolOnto(map) {
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
            title: `School [${schoolLocation.lng}, ${schoolLocation.lat}]`
        })
    }
    schoolMarker.setPosition(schoolLocation)
}

let circleClickListener = null
const setupMapCallbacks = (app, clickable) => (data) => {
    const map = data
    if (clickable) {
        if (!google.maps.event.hasListeners(map, "click")) {
            circleClickListener = google.maps.event.addListener(map, "click", function (args) {
                const pos = {
                    lat: args.latLng.lat(),
                    lng: args.latLng.lng()
                }
                insertCircle(pos, app, map)
            })
        }
    } else {
        if (circleClickListener) {
            google.maps.event.removeListener(circleClickListener)
        }
    }

    return Promise.resolve(data)
}


function insertCircle(pos, app, map, radius = 50) {

    if (schoolCircle) {
        radius = schoolCircle.getRadius()
        schoolCircle.setMap(null)
    }

    schoolCircle = new google.maps.Circle({
        strokeColor: darkGreen,
        strokeOpacity: 0.8,
        strokeWeight: 2,
        fillColor: darkGreen,
        fillOpacity: 0.35,
        map: map,
        draggable: editable,
        geodesic: true,
        editable: editable,
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
    if (!google.maps.event.hasListeners(schoolCircle, "radius_changed")) {
        google.maps.event.addListener(schoolCircle, "radius_changed", function () {
            sendSchoolCircle(schoolCircle)
        })
        google.maps.event.addListener(schoolCircle, "center_changed", function () {

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
                    title: `School [${schoolCircle.center.lng}, ${schoolCircle.center.lat}]`
                })
            }
            schoolMarker.setPosition(schoolCircle.center)
            sendSchoolCircle(schoolCircle)
        })
    }

    map.panTo(schoolCircle.center)
    map.setZoom(17)
    sendSchoolCircle(schoolCircle)
}


let polylines = []
let polylineMarkers = []
let markerIdx = 0

function rerenderPolylines() {
    polylineMarkers.forEach((val, _idx, array) => {
        const isMarker = _idx % 2 == 0
        if (!isMarker) {
            val.setPath([
                polylineMarkers[_idx - 1].position,
                polylineMarkers[_idx + 1].position

            ])
        }
    })
}
function updatePolyline(app) {
    rerenderPolylines()

    const locations = polylineMarkers
        .filter((_1, idx, _2) => {
            const isMarker = idx % 2 == 0
            return isMarker
        }).map((v, _1, _2) => {
            return {
                lat: v.position.lat(),
                lng: v.position.lng()
            }
        })

    app.ports.updatedPath.send(locations)
}

let mapClickListener = null
const addDrawTools = (app, drawable) => (data) => {
    const map = data

    if (drawable) {
        if (!mapClickListener) {
            mapClickListener = google.maps.event.addListener(map, "click", function (args) {
                markerIdx += 1
                renderPathPoint(args.latLng, map, app, markerIdx)
            })
        }
    } else {
        google.maps.event.removeListener(mapClickListener)
        mapClickListener = null
    }

    return Promise.resolve(data)
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
        insertCircle(pos, app, MapDomElement)
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
let homeMarkerMapClickListener
function initializeSearch(app) {
    sleep(100).then(() => {

        const setup = initializeMaps(app)
            .then((map) => {
                setupHomeMarker(app, map)

                if (!google.maps.event.hasListeners(map, "click")) {
                    homeMarkerMapClickListener = google.maps.event.addListener(map, "click", function (args) {
                        homeMarker.setPosition(args.latLng)
                        app.ports.receivedMapLocation.send({
                            lat: args.latLng.lat(),
                            lng: args.latLng.lng()
                        })
                    })
                }

                var input = document.getElementById("search-input")

                var autocomplete = new google.maps.places.Autocomplete(input)

                autocomplete.bindTo("bounds", map)

                // Set the data fields to return when the user selects a place.
                autocomplete.setFields(
                    ["address_components", "geometry", "name"])
                autocomplete.addListener("place_changed", function () {

                    homeMarker.setVisible(false)
                    var place = autocomplete.getPlace()
                    if (!place.geometry) {
                        window.alert("No details available for input: " + place.name)
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

                    var address = ""
                    if (place.address_components) {
                        address = [
                            (place.address_components[0] && place.address_components[0].short_name || ""),
                            (place.address_components[1] && place.address_components[1].short_name || ""),
                            (place.address_components[2] && place.address_components[2].short_name || "")
                        ].join(" ")
                    }
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

    homeMarkerDragListener = google.maps.event.addListener(homeMarker, "dragend", function () {
        app.ports.receivedMapLocation.send({
            lat: homeMarker.getPosition().lat(),
            lng: homeMarker.getPosition().lng()
        })
    })
}

function fitBoundsMap(map) {
    var bounds = new google.maps.LatLngBounds()

    const extendBounds = (mapObject) => {
        if (mapObject.getPath) {
            mapObject.getPath().getArray().forEach(extendBounds)
        } else if (mapObject.position) {
            bounds.extend(mapObject.position)
        } else if (mapObject.bounds && mapObject.bounds.getNorthEast) {
            bounds.extend(mapObject.bounds.getNorthEast())
            bounds.extend(mapObject.bounds.getSouthWest())
        } else {
            bounds.extend(mapObject)
        }
    }

    polylines.forEach(extendBounds)
    markers.forEach(extendBounds)
    tiles.forEach(extendBounds)
    polylineMarkers.forEach(extendBounds)
    extendBounds(schoolMarker)

    map.fitBounds(bounds)
}

function setupMapPorts(app) {

    app.ports.cleanMap.subscribe((_) => {
        cleanMap()
    })
    app.ports.disableClickListeners.subscribe((_) => {
        disableClickListeners(2000)
    })

    // One time actions, we don't want too many subscriptions
    const updateMarker = function ({ location, bearing, markerID, bus }) {
        initializeMaps(app, false, false, 0)
            .then((map) => {
                console.log(markerID, bus)
                var id = bus

                if (markerID) {
                    id = markerID
                }


                var marker = markers.find((value, _indx, _list) => {
                    return value.id == id
                })

                if (marker === undefined) {

                    marker = new google.maps.Marker({
                        id: id,
                        map: map,
                        title: "Bus Trip"
                    })
                    markers.push(marker)
                    var image = {
                        // url: `/images/buses/${getCardinalDirection(bearing)}.svg`,
                        url: `/images/buses/N.svg`,
                        size: new google.maps.Size(90, 90),
                        anchor: new google.maps.Point(45, 45),
                        scaledSize: new google.maps.Size(90, 90)
                    }
                    marker.setIcon(image)
                }

                marker.setPosition(location)

                map.panTo(location)

                document.querySelectorAll('img[src="/images/buses/N.svg"]').forEach((node) => {
                    node.style["transform"] = `rotate(${bearing}deg)`
                    node.style["webkitTransform"] = `rotate(${bearing}deg)`
                    node.style["MozTransform"] = `rotate(${bearing}deg)`
                    node.style["msTransform"] = `rotate(${bearing}deg)`
                    node.style["OTransform"] = `rotate(${bearing}deg)`
                })
            })
    }

    app.ports.updateBusMap.subscribe((update) => {
        initializeMaps(app)
            .then((map) => {
                updateMarker(update)
            })
    })

    app.ports.bulkUpdateBusMap.subscribe((updates) => {
        initializeMaps(app)
            .then((map) => {
                updates.forEach((update) => {

                    updateMarker(update)
                })
            })
    })

    // Trips Map Callbacks
    app.ports.deselectPoint.subscribe(() => {

        markers.forEach((x) => {
            x.setMap(null)
        })
        markers = []
    })

    app.ports.selectPoint.subscribe(({ location, bearing }) => {
        const markerID = "trip"
        updateMarker({ location: location, bearing: bearing, markerID: markerID })
    })

    app.ports.showHomeLocation.subscribe((location) => {
        initializeMaps(app)
            .then((map) => {
                setupHomeMarker(app, map)

                homeMarker.setPosition(location)
            })
    })

    app.ports.showHomeLocation.subscribe((location) => {
        initializeMaps(app)
            .then((map) => {
                setupHomeMarker(app, map)
                homeMarker.setPosition(location)
            })
    })

    app.ports.highlightPath.subscribe(({ routeID, highlighted }) => {
        const performHighlighting = () => {
            let polyline = polylines.find((value, _indx, _list) => {
                return value.id == routeID
            })
            if (polyline) {
                if (highlighted) {
                    polyline.set("strokeColor", purple)
                } else {
                    polyline.set("strokeColor", darkGreen)
                }
            }
        }
        if (MapLibraryInstance) {
            performHighlighting()
        } else {
            initializeMaps(app)
                .then(performHighlighting)
        }
    })

    const drawPath = (map, editable = false) => ({ routeID, path, highlighted }) => {

        if (editable) {
            addDrawTools(app, true)(map).then((_map) => {
                path.forEach((position, idx, _array) => {
                    renderPathPoint(position, map, app, idx)
                })
            })
        } else {
            let polyline = polylines.find((value, _indx, _list) => {
                return value.id == routeID
            })
            if (!polyline) {

                polyline = new google.maps.Polyline({
                    geodesic: false,
                    strokeColor: highlighted ? purple : darkGreen,
                    editable: editable,
                    id: routeID
                })
                polylines.push(polyline)
            } else {
                polyline.setMap(null)
            }
            if (highlighted) {
                polyline.set("strokeColor", purple)
            } else {
                polyline.set("strokeColor", darkGreen)
            }

            polyline.setPath(path)
            polyline.setMap(map)
        }
    }

    app.ports.drawPath.subscribe((path) => {
        initializeMaps(app)
            .then((map) => {
                sleep(100).then(() => {
                    drawPath(map)(path)
                })
            })
    })

    app.ports.drawEditablePath.subscribe((path) => {
        initializeMaps(app)
            .then((map) => {
                sleep(200).then(() => {
                    drawPath(map, true)(path)
                    sleep(100).then(() => {
                        fitBoundsMap(map)
                    })
                })
            })
    })

    app.ports.bulkDrawPath.subscribe((paths) => {
        initializeMaps(app)
            .then((map) => {
                if (initializingMapsChain) {
                    initializingMapsChain.then((map) => {

                        pushSchoolOnto(map)
                        paths.forEach(drawPath(map))
                    })
                } else {
                    pushSchoolOnto(map)
                    paths.forEach(drawPath(map))
                }
            })
    })
    app.ports.insertCircle.subscribe(({ location, radius }) => {
        initializeMaps(app)
            .then((map) => {
                sleep(100).then(() => {
                    insertCircle(location, app, map, radius)
                })
            })
    })

    app.ports.fitBoundsMap.subscribe(() => {
        initializeMaps(app)
            .then((map) => {
                sleep(400).then(() => {
                    fitBoundsMap(map)
                })
            })
    })

    function setTilesVisibility(map, visible) {
        const setMap = (mapValue) => (tile) => {
            tile.setMap(mapValue)
        }
        if (visible) {
            tiles.forEach(setMap(map))
        } else {
            tiles.forEach(setMap(null))
        }
    }

    app.ports.drawDeviationTiles.subscribe(({ correct, deviation, visible }) => {
        initializeMaps(app)
            .then((map) => {

                cleanGrid()

                const drawTile = (color, strokeWeight) => (tile) => {
                    var rectangle = new google.maps.Rectangle({
                        strokeColor: color,
                        strokeOpacity: 0.8,
                        strokeWeight: strokeWeight,
                        fillColor: color,
                        fillOpacity: 0.35,
                        map: map,
                        bounds: {
                            north: tile.topRight.lat,
                            south: tile.bottomLeft.lat,
                            east: tile.topRight.lng,
                            west: tile.bottomLeft.lng
                        }
                    })

                    tiles.push(rectangle)
                }

                correct.forEach(drawTile(darkGreen, 3))
                deviation.forEach(drawTile(errorRed, 2))

                setTilesVisibility(map, visible)
            })
    })

    app.ports.setDeviationTileVisible.subscribe((visible) => {
        initializeMaps(app)
            .then((map) => {
                setTilesVisibility(map, visible)
            })
    })
}

function renderPathPoint(position, map, app, markerIdx) {
    var marker = new google.maps.Marker({
        id: markerIdx.toString(),
        position: position,
        icon: {
            url: "/images/handle.svg",
            size: new google.maps.Size(28, 28),
            anchor: new google.maps.Point(7, 7),
            scaledSize: new google.maps.Size(14, 14)
        },
        draggable: true,
        map: map,
    })

    let polyline

    if (polylineMarkers.length === 0) {
        polylineMarkers.push(marker)
    }
    else {
        const lastMarker = polylineMarkers[polylineMarkers.length - 1]
        polyline = new google.maps.Polyline({
            path: [lastMarker.position, marker.position],
            map: map,
            id: markerIdx.toString()
        })
        polyline.set("strokeColor", darkGreen)
        polylineMarkers.push(polyline)
        polylineMarkers.push(marker)
    }
    google.maps.event.addListener(marker, "click", function (args) {
        polylineMarkers = polylineMarkers.filter((val, _, _2) => {
            return val.id !== marker.id
        })
        if (polyline) {
            polyline.setMap(null)
            polyline = null
        }
        marker.setMap(null)
        marker = null
        updatePolyline(app)
    })
    google.maps.event.addListener(marker, "dragend", function (args) {
        updatePolyline(app)
    })
    updatePolyline(app)
}

function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time))
}

export {
    initializeMaps,
    requestGeoLocation,
    initializeSearch,
    schoolLocationStorageKey,
    setupMapPorts,
    loadMapAPI,
    cleanMap
}