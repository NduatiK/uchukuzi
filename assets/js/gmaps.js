import mapStyles from './mapStyles'


function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time))
}

let MapInstance
let DomElement
let markers

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
    // console.log("loaded")
    var myLatlng = new google.maps.LatLng(0, 0)

    var mapOptions = {
        zoom: 6,
        center: myLatlng,
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
        // center: opt.location,
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
            .then(createMapElement({ lat: 0, lng: 0 }))
    } else {

        return Promise.resolve({
            dom: DomElement
        })
    }
}

function initializeMaps(app, numberOfRetries) {

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
            mapDiv.appendChild(dom)

            if (!markers) {
                markers = []
            } else {
                markers.forEach((x) => {
                    x.setMap(null)
                })
                markers = []
            }

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

            google.maps.event.addListener(MapInstance, 'click', function (args) {
                const pos = {
                    lat: args.latLng.lat(),
                    lng: args.latLng.lng()
                }
                console.log('latlng', pos)
            })
        })

}


export { initializeMaps }