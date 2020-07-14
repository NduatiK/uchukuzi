
import mapStyles from "./mapStyles"
import * as  Cache from "./cache"
import { Elm } from "../elm/Main"
import { sleep } from "./sleep"
import { Colors } from "./colors"


type ElmLatLng = {
    lng: number;
    lat: number;
}

type ElmPath = {
    routeID: number;
    path: ElmLatLng[];
    highlighted: boolean;
}
type ElmTile = {
    bottomLeft: ElmLatLng;
    topRight: ElmLatLng;
}

type ElmTileCollection = {
    values: ElmTile[];
    visible: boolean;
}


let schoolLocation: ElmLatLng | null = Cache.getSchoolLocation()

window.addEventListener("storage", (event) => {
    const location = Cache.getSchoolLocation()

    if (Map && schoolLocation !== location) {
        schoolLocation = location
        pushSchoolOnto(Map)
    }
}, false)


// Prevent duplicate loads
let runningRequest: Promise<any> | null = null
let initializingMapsChain = null

let defaultLocation = { center: { lat: -1.2921, lng: 36.8219 }, zoom: 16 }

if (schoolLocation) {
    defaultLocation = { center: schoolLocation, zoom: 16 }
}

var editable = true

/**
 * Completely sets up the map for a page
 */
function initializeMaps(app: Elm.Main.App, clickable = false, drawable = false, sleepTime = 800) {
    editable = clickable || drawable
    if (schoolLocation) {
        const credentialsStorageKey = "credentials"
        const storedCredentials = Cache.getCredentials()
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
    } else if (runningRequest) {
        return runningRequest
    } else {


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
}

let Map: google.maps.Map | null = null
let MapDomElement: HTMLElement | null = null

/**
 * Creates a GMAPs Library Map instance and its dom element for reuse across the application
 */
function createMapDom() {
    runningRequest = null
    if (MapDomElement && Map) {
        return Promise.resolve({ dom: MapDomElement, map: Map })
    }

    var mapOptions = {
        panControl: false,
        zoomControl: true,
        zoomControlOptions: {
            style: google.maps.ZoomControlStyle.SMALL,
            position: google.maps.ControlPosition.TOP_RIGHT
        },
        mapTypeControl: false,
        streetViewControl: false,
        clickableIcons: false,
        overviewMapControl: false,
        ...defaultLocation,
        styles: mapStyles,
    }

    const newElement = document.createElement("google-map-cached")
    Map = new google.maps.Map(newElement, mapOptions)
    MapDomElement = newElement

    return Promise.resolve({ dom: MapDomElement, map: Map })
}

let markers: google.maps.Marker[] = []
let correctTiles: google.maps.Rectangle[] = []
let deviationTiles: google.maps.Rectangle[] = []
let drawingManager = null
let schoolCircle: google.maps.Circle | null = null
let schoolCircleRadiusListener: google.maps.MapsEventListener | null = null

/**
 * Places the map within a google-map dom element
 */
const insertMap = (sleepTime: number) => (data: { dom: Element, map: google.maps.Map }) => {
    return sleep(sleepTime).then(() => {
        const { dom, map } = data

        var mapDiv = document.getElementById("google-map")

        if (dom.parentNode) {
            dom.parentNode.removeChild(dom)
        }
        mapDiv?.prepend(dom)
        pushSchoolOnto(map)
        return Promise.resolve(map)
    })
}

/**
 * Removes items from the map before reuse
 */
function cleanMap() {
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


    cleanGrid()

    if (schoolCircle) {
        schoolCircle.setMap(null)
    }

    disableClickListeners(0)

    // Reset location
    if (Map) {
        const map = Map
        map.panTo(new google.maps.LatLng(defaultLocation.center))
        map.setZoom(defaultLocation.zoom)

        pushSchoolOnto(map)
    }
}


function cleanGrid() {
    correctTiles.forEach((x) => {
        x.setMap(null)
    })
    correctTiles = []

    deviationTiles.forEach((x) => {
        x.setMap(null)
    })
    deviationTiles = []
}

function disableClickListeners(time = 300) {
    sleep(time).then(() => {

        if (Map) {
            google.maps.event.clearInstanceListeners(Map)
            homeMarkerMapClickListener = null
            homeMarkerDragListener = null
            circleClickListener = null
            mapClickListener = null
            schoolCircleRadiusListener = null
            homeMarker?.setDraggable(false)
        }
    })
}

var schoolMarker: google.maps.Marker | null = null

/**
 * Displaces the location of the school on the map
 */
function pushSchoolOnto(map: google.maps.Map) {
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

let circleClickListener: google.maps.MapsEventListener | null = null
const setupMapCallbacks = (app: Elm.Main.App, clickable: boolean) => (map: google.maps.Map) => {
    if (clickable) {
        if (!circleClickListener) {
            circleClickListener = google.maps.event.addListener(map, "click", function (args) {
                insertCircle(args.latLng, app, map)
            })
        }
    } else {
        if (circleClickListener) {
            google.maps.event.removeListener(circleClickListener)
        }
    }

    return Promise.resolve(map)
}


function insertCircle(pos: google.maps.LatLng, app: Elm.Main.App, map: google.maps.Map, radius = 50) {

    if (schoolCircle) {
        radius = schoolCircle.getRadius()
        schoolCircle.setMap(null)
    }

    schoolCircle = new google.maps.Circle({
        strokeColor: Colors.darkGreen,
        strokeOpacity: 0.8,
        strokeWeight: 2,
        fillColor: Colors.darkGreen,
        fillOpacity: 0.35,
        map: map,
        draggable: editable,
        editable: editable,
        center: pos,
        radius: radius // metres
    })

    function updateSchoolCircle(schoolCircle: google.maps.Circle) {
        if (schoolMarker) {
            schoolMarker.setPosition(schoolCircle.getCenter())
        }

        app.ports.receivedMapClickLocation.send({
            location: {
                lat: schoolCircle.getCenter().lat(),
                lng: schoolCircle.getCenter().lng()
            },
            radius: schoolCircle.getRadius()
        })
    }

    if (!schoolCircleRadiusListener) {
        schoolCircleRadiusListener = google.maps.event.addListener(schoolCircle, "radius_changed", function () {
            if (schoolCircle) {
                updateSchoolCircle(schoolCircle)
            }
        })
        google.maps.event.addListener(schoolCircle, "center_changed", function () {
            if (schoolCircle) {
                const center = schoolCircle.getCenter()

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
                        title: `School [${center.lng}, ${center.lat}]`
                    })
                }
                updateSchoolCircle(schoolCircle)
            }
        })
    }
    if (schoolCircle) {
        map.panTo(schoolCircle.getCenter())
    }
    map.setZoom(17)
    updateSchoolCircle(schoolCircle)
}


let polylines: google.maps.Polyline[] = []
let polylineMarkers: (google.maps.Marker | google.maps.Polyline)[] = []
let markerIdx = 0

function rerenderPolylines() {

    polylineMarkers.forEach((val, _idx, array) => {

        if (val instanceof google.maps.Polyline) {
            const shapeBefore = polylineMarkers[_idx - 1]
            const shapeAfter = polylineMarkers[_idx + 1]

            if (shapeBefore instanceof google.maps.Marker &&
                shapeAfter instanceof google.maps.Marker) {
                const positionBefore = shapeBefore.getPosition()
                const positionAfter = shapeAfter.getPosition()

                if (positionBefore instanceof google.maps.LatLng &&
                    positionAfter instanceof google.maps.LatLng) {

                    val.setPath([positionBefore, positionAfter])
                }
            }
        }
    })
}
function updatePolyline(app: Elm.Main.App) {
    rerenderPolylines()

    const locations = polylineMarkers
        .reduce((results, v) => {
            if (v instanceof google.maps.Marker) {
                const pos = v.getPosition()
                if (pos) {
                    results.push({
                        lat: pos.lat(),
                        lng: pos.lng()
                    })
                }
            }
            return results
        }, <ElmLatLng[]>[])

    app.ports.updatedPath.send(locations)
}

let mapClickListener: google.maps.MapsEventListener | null = null
const addDrawTools = (app: Elm.Main.App, drawable: boolean) => (map: google.maps.Map) => {
    if (drawable) {
        if (!mapClickListener) {
            mapClickListener = google.maps.event.addListener(map, "click", function (args) {
                markerIdx += 1
                renderPathPoint(args.latLng, map, app, markerIdx)
            })
        }
    } else {
        if (mapClickListener) {
            google.maps.event.removeListener(mapClickListener)
            mapClickListener = null
        }
    }

    return Promise.resolve(map)
}
const requestGeoLocation = (app: Elm.Main.App) => () => {

    function handleLocationError(error: PositionError) {
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

    const success = (position: Position) => {
        const pos = new google.maps.LatLng({
            lat: position.coords.latitude,
            lng: position.coords.longitude,
        })
        if (Map) {
            insertCircle(pos, app, Map, 50)
        }
    }

    const failure = (error: PositionError) => {
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

let homeMarker: google.maps.Marker | null
let homeMarkerMapClickListener: google.maps.MapsEventListener | null
const initializeSearch = (app: Elm.Main.App) => () => {
    sleep(100).then(() => {

        const setup = initializeMaps(app)
            .then((map) => {
                setupHomeMarker(app, map)

                if (!homeMarkerMapClickListener) {
                    homeMarkerMapClickListener = google.maps.event.addListener(map, "click", function (args) {
                        homeMarker?.setPosition(args.latLng)
                        app.ports.receivedMapLocation.send({
                            lat: args.latLng.lat(),
                            lng: args.latLng.lng()
                        })
                    })
                }

                var input = document.getElementById("search-input") as HTMLInputElement

                if (input) {

                    var autocomplete = new google.maps.places.Autocomplete(input)

                    autocomplete.bindTo("bounds", map)

                    // Set the data fields to return when the user selects a place.
                    autocomplete.setFields(
                        ["address_components", "geometry", "name"])
                    autocomplete.addListener("place_changed", function () {

                        homeMarker?.setVisible(false)
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
                        homeMarker?.setPosition(place.geometry.location)
                        homeMarker?.setVisible(true)

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
                }
            })
            .catch((e) => {
                console.log(e)
                app.ports.autocompleteError.send(true)
            })
    })
}

var homeMarkerDragListener

function setupHomeMarker(app: Elm.Main.App, map: google.maps.Map, draggable = true) {
    if (homeMarker) {
        homeMarker.setDraggable(draggable)
        return
    }
    var image = {
        url: "/images/home_pin.svg",
        size: new google.maps.Size(24, 24),
        anchor: new google.maps.Point(12, 24),
    }
    homeMarker = new google.maps.Marker({
        draggable: draggable,
        map: map,
        icon: image
    })

    homeMarkerDragListener = google.maps.event.addListener(homeMarker, "dragend", function () {
        const position = homeMarker?.getPosition()
        if (position) {
            app.ports.receivedMapLocation.send({
                lat: position.lat(),
                lng: position.lng()
            })
        }
    })
}

function fitBoundsMap(map: google.maps.Map, objects?: any) {

    var bounds = new google.maps.LatLngBounds()

    const extendBounds = (mapObject: google.maps.Polyline | google.maps.Rectangle | google.maps.Marker | google.maps.LatLng) => {
        if (mapObject instanceof google.maps.Polyline) {
            mapObject.getPath().getArray().forEach(extendBounds)
        } else if (mapObject instanceof google.maps.Marker) {
            const pos = mapObject.getPosition()
            if (pos instanceof google.maps.LatLng) {
                bounds.extend(pos)
            }
        } else if (mapObject instanceof google.maps.Rectangle) {
            bounds.extend(mapObject.getBounds().getNorthEast())
            bounds.extend(mapObject.getBounds().getSouthWest())
        } else {
            bounds.extend(mapObject)
        }
    }

    if (!objects) {
        polylines.forEach(extendBounds)
        markers.forEach(extendBounds)
        correctTiles.forEach(extendBounds)
        deviationTiles.forEach(extendBounds)
        polylineMarkers.forEach(extendBounds)
        if (schoolMarker) {
            extendBounds(schoolMarker)
        }
    } else {
        objects.forEach(extendBounds)
    }

    map.fitBounds(bounds)
}

function setupInterop(app: Elm.Main.App) {

    app.ports.cleanMap.subscribe((_) => {
        cleanMap()
    })
    app.ports.disableClickListeners.subscribe((_) => {
        disableClickListeners()
    })

    // One time actions, we don't want too many subscriptions
    const updateMarker = function (data:
        {
            bus: number;
            location: ElmLatLng;
            bearing: number;
        }) {
        initializeMaps(app, false, false, 0)
            .then((map) => {

                const { location, bearing, bus } = data

                var id = bus

                var marker = markers.find((value, _indx, _list) => {
                    return value.get("id") == id
                })

                if (marker === undefined) {

                    marker = new google.maps.Marker({
                        map: map,
                        title: "Bus"
                    })

                    marker.set("id", id)

                    markers.push(marker)
                    var image = {
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
                    var htmlNode = (node as HTMLElement)
                    if (htmlNode) {
                        htmlNode.style["transform"] = `rotate(${bearing}deg)`
                        htmlNode.style["webkitTransform"] = `rotate(${bearing}deg)`
                    }
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
        // const markerID = "trip"
        const markerID = -10
        updateMarker({ location: location, bearing: bearing, bus: markerID })
    })


    app.ports.showHomeLocation.subscribe(({ location, draggable }) => {
        initializeMaps(app)
            .then((map) => {
                sleep(200).then(() => {
                    setupHomeMarker(app, map, draggable)
                    homeMarker?.setPosition(location)
                    fitBoundsMap(map, [schoolMarker, homeMarker])
                })
            })
    })


    app.ports.highlightPath.subscribe(({ routeID, highlighted }) => {
        const performHighlighting = () => {
            let polyline = polylines.find((value, _indx, _list) => {
                return value.get("id") == routeID
            })
            if (polyline) {
                if (highlighted) {
                    polyline.set("strokeColor", Colors.purple)
                } else {
                    polyline.set("strokeColor", Colors.darkGreen)
                }
            }
        }
        if (Map) {
            performHighlighting()
        } else {
            initializeMaps(app)
                .then(performHighlighting)
        }
    })

    const drawPath = (map: google.maps.Map, editable = false) => (pathData: ElmPath) => {

        const { routeID, path, highlighted } = pathData

        if (editable) {
            addDrawTools(app, true)(map).then((_map) => {
                path.forEach((position, idx, _array) => {
                    renderPathPoint(new google.maps.LatLng(position), map, app, idx)
                })
            })
        } else {
            let polyline = polylines.find((value, _indx, _list) => {
                return value.get("id") == routeID
            })
            if (!polyline) {

                polyline = new google.maps.Polyline({
                    geodesic: false,
                    strokeColor: highlighted ? Colors.purple : Colors.darkGreen,
                    editable: editable
                })
                polyline.set("id", routeID)
                polylines.push(polyline)
            } else {
                polyline.setMap(null)
            }
            if (highlighted) {
                polyline.set("strokeColor", Colors.purple)
            } else {
                polyline.set("strokeColor", Colors.darkGreen)
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
                    drawPath(map, path.editable)(path)
                    sleep(100).then(() => {
                        fitBoundsMap(map)
                    })
                })
            })
    })

    app.ports.bulkDrawPath.subscribe((paths) => {
        initializeMaps(app)
            .then((map) => {
                pushSchoolOnto(map)
                paths.forEach(drawPath(map))
            })
    })
    app.ports.insertCircle.subscribe(({ location, radius }) => {
        initializeMaps(app)
            .then((map) => {
                sleep(100).then(() => {
                    insertCircle(new google.maps.LatLng(location), app, map, radius)
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

    function setTilesVisibility(map: google.maps.Map, correctVisible: boolean, deviationVisible: boolean) {

        const setMap = (mapValue: google.maps.Map | null) => (tile: google.maps.Rectangle) => {
            tile.setMap(mapValue)
        }
        if (deviationVisible) {
            deviationTiles.forEach(setMap(map))
        } else {
            deviationTiles.forEach(setMap(null))
        }

        if (correctVisible) {
            correctTiles.forEach(setMap(map))
        } else {
            correctTiles.forEach(setMap(null))
        }
    }

    app.ports.drawDeviationTiles.subscribe(({ correct, deviation }) => {
        initializeMaps(app)
            .then((map) => {

                cleanGrid()

                const drawTile = (color: string, strokeWeight: number, isCorrect: boolean) => (tile: ElmTile) => {
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

                    if (isCorrect) {
                        correctTiles.push(rectangle)
                    } else {
                        deviationTiles.push(rectangle)
                    }
                }

                correct.values.forEach(drawTile(Colors.darkGreen, 3, true))
                deviation.values.forEach(drawTile(Colors.errorRed, 2, false))

                setTilesVisibility(map, correct.visible, deviation.visible)
            })
    })

    app.ports.setDeviationTileVisible.subscribe(({ correctVisible, deviationVisible }) => {
        initializeMaps(app)
            .then((map) => {
                setTilesVisibility(map, correctVisible, deviationVisible)
            })
    })
}

function renderPathPoint(markerPosition: google.maps.LatLng, map: google.maps.Map, app: Elm.Main.App, markerIdx: number) {
    var marker: google.maps.Marker | null = new google.maps.Marker({
        position: markerPosition,
        icon: {
            url: "/images/handle.svg",
            size: new google.maps.Size(28, 28),
            anchor: new google.maps.Point(7, 7),
            scaledSize: new google.maps.Size(14, 14)
        },
        draggable: true,
        map: map,
    })

    marker.set("id", markerIdx.toString())

    let polyline: google.maps.Polyline | null

    if (polylineMarkers.length === 0) {
        polylineMarkers.push(marker)
    } else {
        const lastMarker = polylineMarkers[polylineMarkers.length - 1]
        var last
        if (lastMarker instanceof google.maps.Marker) {
            last = lastMarker.getPosition() as google.maps.LatLng
        } else {
            last = markerPosition
        }

        polyline = new google.maps.Polyline({
            path: [last, markerPosition],
            map: map
        })
        polyline.set("id", markerIdx)
        polyline.set("strokeColor", Colors.darkGreen)
        polylineMarkers.push(polyline)
        polylineMarkers.push(marker)
    }
    google.maps.event.addListener(marker, "click", function (args) {
        polylineMarkers = polylineMarkers.filter((val, _, _2) => {
            return val.get("id") !== marker?.get("id")
        })
        if (polyline) {
            polyline.setMap(null)
            polyline = null
        }
        marker?.setMap(null)
        marker = null
        updatePolyline(app)
    })
    google.maps.event.addListener(marker, "dragend", function (args) {
        updatePolyline(app)
    })
    updatePolyline(app)
}



export {
    initializeMaps,
    requestGeoLocation,
    initializeSearch,
    setupInterop,
    loadMapAPI,
    cleanMap
}