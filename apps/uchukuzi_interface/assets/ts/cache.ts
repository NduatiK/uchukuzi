const { localStorage } = window;

interface Credentials {
  email: string;
  token: string;
  name: string;
  school_id: number;
}

export function getCredentials(): Credentials | null {
  const credentials = nullableParse<Credentials>(localStorage.getItem("credentials"));

  if (!credentials) {
    setCredentials(null)
    return null
  }

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
  const location = nullableParse<Location>(localStorage.getItem("schoolLocation"));

  if (!location) {
    return null
  }

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
  const sideBarState = nullableParse<boolean>(localStorage.getItem("sideBarState"))
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

function nullableParse<T>(jsonString: any): T | null {
  try {
    return JSON.parse(jsonString);
  } catch (e) {
    return null;
  }
}
