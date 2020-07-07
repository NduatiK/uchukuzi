const { localStorage } = window;

// interface PhoenixData {
//   tag: string;
//   data: object;
// }
interface Credentials {
  email: string;
  token: string;
  name: string;
  school_id: number;
}

export function getCredentials(): Credentials | null {
  return safeParse(localStorage.getItem("credentials"));
}

export function setCredentials(credentials: Credentials | null) {
  localStorage.setItem("credentials", JSON.stringify(credentials));
  if (credentials == null) {
    setSchoolLocation(null)
  }
  window.dispatchEvent(new Event('storage'))
}

interface Location {
  lat: number;
  lng: number;
}

export function getSchoolLocation(): Location | null {
  return safeParse(localStorage.getItem("schoolLocation"));
}

export function setSchoolLocation(location: Location | null) {
  localStorage.setItem("schoolLocation", JSON.stringify(location));
  window.dispatchEvent(new Event('storage'))
}

export function getSidebarState(): boolean {
  return safeParse(localStorage.getItem("sideBarState")) || true;
}

export function setSidebarState(sideBarOpen: boolean) {
  return localStorage.setItem("sideBarState", JSON.stringify(sideBarOpen));
  window.dispatchEvent(new Event('storage'))
}

export function clear() {
  localStorage.clear();
}

function safeParse(jsonString: any) {
  try {
    return JSON.parse(jsonString);
  } catch (e) {
    return null;
  }
}
