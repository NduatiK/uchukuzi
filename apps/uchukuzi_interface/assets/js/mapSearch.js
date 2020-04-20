// Reference https://developers.google.com/maps/documentation/javascript/reference/coordinates#LatLngBounds

// This example requires the Places library. Include the libraries=places
// parameter when you first load the API. For example:
// <script src="https://maps.googleapis.com/maps/api/js?key=YOUR_API_KEY&libraries=places">

var map;
var service;
var infowindow;



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

function initMap() {
  var sydney = new google.maps.LatLng(-33.867, 151.195);

  infowindow = new google.maps.InfoWindow();

  map = new google.maps.Map(
      document.getElementById('map'), {center: sydney, zoom: 15});

  var request = {
    query: 'Chiromo University Of Nairobi',
    fields: ['name', 'geometry'],
  };

  service = new google.maps.places.PlacesService(map);

  service.findPlaceFromQuery(request, function(results, status) {
    if (status === google.maps.places.PlacesServiceStatus.OK) {
      for (var i = 0; i < results.length; i++) {
        createMarker(results[i]);
      }

      map.setCenter(results[0].geometry.location);
    }
  });
}

function createMarker(place) {
  var marker = new google.maps.Marker({
    map: map,
    position: place.geometry.location
  });

  google.maps.event.addListener(marker, 'click', function() {
    infowindow.setContent(place.name);
    infowindow.open(map, this);
  });
}