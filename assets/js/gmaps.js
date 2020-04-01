import mapStyles from './mapStyles'


function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time))
}

let MapInstance
let DomElement
let markers
let schoolCircle
let clickable = false

const loadMapsApi = () => {
    if (typeof google !== typeof undefined) {
        // console.log("loadMapsApi cache")

        return Promise.resolve()
    }
    // console.log("loadMapsApi no google")

    return new Promise((resolve, reject) => {
        const script = document.createElement('script')
        script.type = 'text/javascript'
        script.onload = resolve
        document.getElementsByTagName('head')[0].appendChild(script)
        script.src = "https://maps.googleapis.com/maps/api/js?key=AIzaSyB6wUhsk2tL7ihoORGBfeqc8UCRA3XRVsw"
    })
}

const createMapElement = (opt) => (geoResult) => {
    var mapOptions = {
        styles: mapStyles,
        zoom: 7,
        panControl: false,
        zoomControl: true,
        zoomControlOptions: {
            style: google.maps.ZoomControlStyle.SMALL,
            position: google.maps.ControlPosition.RIGHT
        },
        mapTypeControl: false,
        streetViewControl: false,
        overviewMapControl: false,
        ...opt,
        style: mapStyles,
        center: new google.maps.LatLng(opt.lat, opt.lng)

    }

    const newElement = document.createElement('google-map-cached')
    MapInstance = new google.maps.Map(newElement, mapOptions)
    DomElement = newElement

    return {
        dom: DomElement
    }
}

const getMapElement = () => {

    if (!DomElement) {

        return loadMapsApi()
            .then(createMapElement({ lat: -1.2921, lng: 36.8219, zoom: 10 }))
    } else {

        return Promise.resolve({
            dom: DomElement
        })
    }
}

function initializeMaps(app, _clickable, numberOfRetries) {
    clickable = _clickable
    var mapDiv = document.getElementById('google-map')

    if (mapDiv === null) {
        numberOfRetries -= 1

        if (numberOfRetries > 0) {
            sleep(500).then(() => {
                initializeMaps(app, numberOfRetries - 1)
            })
        }

        return
    }

    getMapElement()
        .then(({ dom }) => {

            mapDiv.prepend(dom)

            clearMap()

            // outgoing Port: User clicks a button | elm -> js
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
                var marker = new google.maps.Marker({
                    position: gmPos,
                    map: MapInstance,
                    title: 'Golden Gate Bridge',
                    icon: "/images/buses/E.png"


                })
                markers.push(marker)
                var myLatlng = new google.maps.LatLng(gmPos)
                MapInstance.panTo(myLatlng)
            })

            if (!google.maps.event.hasListeners(MapInstance, 'click')) {

                google.maps.event.addListener(MapInstance, 'click', function (args) {
                    const pos = {
                        lat: args.latLng.lat(),
                        lng: args.latLng.lng()
                    }
                    insertCircle(pos, app)

                })
            }
        })



}

function clearMap() {
    if (!markers) {
        markers = []
    } else {
        markers.forEach((x) => {
            x.setMap(null)
        })
        markers = []
    }

    
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
            MapInstance.panTo(schoolCircle.center);
            MapInstance.setZoom(16);
            sendSchoolCircle(schoolCircle)
        })

}

function requestGeoLocation(app) {

    if (process.env.NODE_ENV !== 'production') {
        app.ports.receivedMapClickLocation.send({
            lat: -1.2921, lng: 36.8219, radius: 50
        })
        return;
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



export { initializeMaps, requestGeoLocation }