import { Elm } from "../elm/Main"

import { ElmPhoenixChannels } from './ElmPhoenixChannels';
import * as Cache from "./cache";
import * as CardPrinter from "./cardPrinter";
import * as GMaps from "./gmaps";
import * as Camera from "./camera";
import * as Charts from "./fuelChart";


export function bindPorts(app: Elm.Main.App) {
  const {
    toPhoenix,
    fromPhoenix,
    setOpenState, setSchoolLocation,
    printCardForStudent,
    initializeSearchPort, initializeCustomMap, requestGeoLocation, initializeCamera,
    setCredentials, credentialsChanged, renderChart
  } = app.ports
  new ElmPhoenixChannels({ toPhoenix, fromPhoenix });

  setOpenState.subscribe(Cache.setSidebarState)

  printCardForStudent.subscribe(CardPrinter.printCard)

  initializeSearchPort.subscribe(GMaps.initializeSearch(app))

  initializeCustomMap.subscribe(({ clickable, drawable }) => {
    sleep(100).then(() => {
      if (drawable) {
        GMaps.cleanMap()
      }
      GMaps.initializeMaps(app, clickable, drawable)
    })
  })


  requestGeoLocation.subscribe(GMaps.requestGeoLocation(app))


  initializeCamera.subscribe(Camera.initializeCamera(app))

  setSchoolLocation.subscribe(Cache.setSchoolLocation)

  setCredentials.subscribe((creds) => {
    Cache.setCredentials(creds)
    credentialsChanged.send(creds);
  })


  renderChart.subscribe(Charts.renderChart)
}

function sleep(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time))
}