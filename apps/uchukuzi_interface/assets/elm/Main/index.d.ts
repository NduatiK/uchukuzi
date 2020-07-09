// WARNING: Do not manually modify this file. It was generated using:
// https://github.com/dillonkearns/elm-typescript-interop
// Type definitions for Elm ports

export namespace Elm {
  namespace Main {
    export interface App {
      ports: {
        setCredentials: {
          subscribe(callback: (data: { name: string; email: string; token: string; school_id: number } | null) => void): void
        }
        credentialsChanged: {
          send(data: { name: string; email: string; token: string; school_id: number } | null): void
        }
        setOpenState: {
          subscribe(callback: (data: boolean) => void): void
        }
        toPhoenix: {
          subscribe(callback: (data: { tag: string; data: unknown }) => void): void
        }
        fromPhoenix: {
          send(data: { tag: string; data: unknown }): void
        }
        setSchoolLocation: {
          subscribe(callback: (data: { lng: number; lat: number } | null) => void): void
        }
        initializeCustomMap: {
          subscribe(callback: (data: { drawable: boolean; clickable: boolean }) => void): void
        }
        fitBoundsMap: {
          subscribe(callback: (data: null) => void): void
        }
        setDeviationTileVisible: {
          subscribe(callback: (data: { correctVisible: boolean; deviationVisible: boolean }) => void): void
        }
        drawDeviationTiles: {
          subscribe(callback: (data: { correct: { values: { bottomLeft: { lng: number; lat: number }; topRight: { lng: number; lat: number } }[]; visible: boolean }; deviation: { values: { bottomLeft: { lng: number; lat: number }; topRight: { lng: number; lat: number } }[]; visible: boolean } }) => void): void
        }
        initializeSearchPort: {
          subscribe(callback: (data: null) => void): void
        }
        requestGeoLocation: {
          subscribe(callback: (data: null) => void): void
        }
        initializeCamera: {
          subscribe(callback: (data: null) => void): void
        }
        disableCamera: {
          subscribe(callback: (data: number) => void): void
        }
        setFrameFrozen: {
          subscribe(callback: (data: boolean) => void): void
        }
        selectPoint: {
          subscribe(callback: (data: { location: { lat: number; lng: number }; bearing: number }) => void): void
        }
        deselectPoint: {
          subscribe(callback: (data: null) => void): void
        }
        updateBusMap: {
          subscribe(callback: (data: { bus: number; location: { lng: number; lat: number }; speed: number; bearing: number }) => void): void
        }
        bulkUpdateBusMap: {
          subscribe(callback: (data: { bus: number; location: { lng: number; lat: number }; speed: number; bearing: number }[]) => void): void
        }
        printCardForStudent: {
          subscribe(callback: (data: string) => void): void
        }
        drawEditablePath: {
          subscribe(callback: (data: { routeID: number; path: { lng: number; lat: number }[]; highlighted: boolean; editable: boolean }) => void): void
        }
        drawPath: {
          subscribe(callback: (data: { routeID: number; path: { lng: number; lat: number }[]; highlighted: boolean }) => void): void
        }
        bulkDrawPath: {
          subscribe(callback: (data: { routeID: number; path: { lng: number; lat: number }[]; highlighted: boolean }[]) => void): void
        }
        showHomeLocation: {
          subscribe(callback: (data: { location: { lng: number; lat: number }; draggable: boolean }) => void): void
        }
        highlightPath: {
          subscribe(callback: (data: { routeID: number; highlighted: boolean }) => void): void
        }
        cleanMap: {
          subscribe(callback: (data: null) => void): void
        }
        disableClickListeners: {
          subscribe(callback: (data: null) => void): void
        }
        insertCircle: {
          subscribe(callback: (data: { location: { lng: number; lat: number }; radius: number }) => void): void
        }
        renderChart: {
          subscribe(callback: (data: { x: number[]; y: { consumptionOnDate: number[]; runningAverage: number[] }; statistics: { stdDev: number; mean: number } | null }) => void): void
        }
        receiveCameraActive: {
          send(data: boolean): void
        }
        scannedDeviceCode: {
          send(data: string): void
        }
        noCameraFoundError: {
          send(data: boolean): void
        }
        receivedMapClickLocation: {
          send(data: { location: { lng: number; lat: number }; radius: number } | null): void
        }
        receivedMapLocation: {
          send(data: { lng: number; lat: number }): void
        }
        onBusMove: {
          send(data: { bus: number; location: { lng: number; lat: number }; speed: number; bearing: number }): void
        }
        autocompleteError: {
          send(data: boolean): void
        }
        updatedPath: {
          send(data: { lng: number; lat: number }[]): void
        }
      };
    }
    export function init(options: {
      node?: HTMLElement | null;
      flags: { creds: { name: string; email: string; token: string; school_id: number } | null; window: { width: number; height: number }; isLoading: boolean; sideBarIsOpen: boolean; hasLoadError: boolean } | null;
    }): Elm.Main.App;
  }
}