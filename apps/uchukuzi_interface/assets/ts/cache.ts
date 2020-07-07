const { localStorage } = window;

interface Credentials {
  email: string;
  token: string;
  name: string;
  school_id: number;
}

export function getCredentials(): Credentials | null {
  const credentials = safeParse(localStorage.getItem("credentials"));

  if (credentials.email && typeof credentials.email == "string" &&
    credentials.token && typeof credentials.token == "string" &&
    credentials.name && typeof credentials.name == "string" &&
    credentials.school_id && typeof credentials.school_id == "number") {
    return credentials
  } else {
    setCredentials(null)
    return null
  }
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
  const location = safeParse(localStorage.getItem("schoolLocation"));
  if ("lat" in location && "lng" in location) {
    return location
  } else {
    return null
  }


}

export function setSchoolLocation(location: Location | null) {
  localStorage.setItem("schoolLocation", JSON.stringify(location));
  window.dispatchEvent(new Event('storage'))
}

export function getSidebarState(): boolean {
  const sideBarState = safeParse(localStorage.getItem("sideBarState"))
  if (typeof sideBarState == "boolean") {
    return sideBarState;
  } else {
    setSidebarState(true)
    return true;
  }
}

export function setSidebarState(sideBarOpen: boolean) {
  return localStorage.setItem("sideBarState", JSON.stringify(sideBarOpen));
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
