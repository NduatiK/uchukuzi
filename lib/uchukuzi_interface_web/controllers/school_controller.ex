defmodule UchukuziInterfaceWeb.SchoolController do
  use UchukuziInterfaceWeb, :controller

  alias Uchukuzi.School
  action_fallback(UchukuziInterfaceWeb.FallbackController)

  def create_school(conn, %{"manager" => manager_params, "school" => school_params}) do
    with center <- %{
           lng: school_params["geo"]["lng"],
           lat: school_params["geo"]["lat"]
         },
         geofence <- %{
           radius: school_params["geo"]["radius"],
           center: center
         },
         school <- School.School.new(school_params["name"], geofence),
         {:ok, %{manager: manager, school: _school}} <-
           School.create_school(school, manager_params) do
      manager = Repo.preload(manager, :school)

      conn
      |> put_status(:created)
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("manager.json", manager: manager, token: ManagerAuth.sign(manager.id))
    end
  end

  def create_houshold(conn, %{
        "guardian" => guardian_params,
        "students" => students_params,
        "pickup_location" => pickup_location_params,
        "home_location" => home_location_params,
        "route" => route_id
      }) do
    with pickup_location <- %{
           lng: pickup_location_params["lng"],
           lat: pickup_location_params["lat"]
         },
         home_location <- %{
           lng: home_location_params["lng"],
           lat: home_location_params["lat"]
         },
         {:ok, %{guardian: guardian}} <-
           School.create_household(
             conn.assigns.manager.school_id,
             guardian_params,
             students_params,
             pickup_location,
             home_location,
             route_id
           ) do
      guardian = Repo.preload(guardian, :students)

      conn
      |> put_status(:created)
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("guardian.json", guardian: guardian)
    end
  end

  def list_households(conn, _) do
    guardians =
      for guardian <- School.guardians_for(conn.assigns.manager.school_id) do
        Repo.preload(guardian, :students)
      end

    conn
    |> put_view(UchukuziInterfaceWeb.RolesView)
    |> render("guardians.json", guardians: guardians)
  end

  def create_bus(conn, bus_params) do
    with {:ok, bus} <- School.create_bus(conn.assigns.manager.school_id, bus_params) do
      bus = Repo.preload(bus, :device)

      conn
      |> put_status(:created)
      |> render("bus.json", bus: bus)
    end
  end

  def list_buses(conn, _) do
    buses =
      for bus <- School.buses_for(conn.assigns.manager.school_id) do
        {Repo.preload(bus, :device), Uchukuzi.Tracking.status_of(bus)}
      end

    conn
    |> render("buses.json", buses: buses)
  end

  def get_bus(conn, %{"bus_id" => bus_id}) do
    with {bus_id, ""} <- Integer.parse(bus_id),
         {:ok, bus} <- School.bus_for(conn.assigns.manager.school_id, bus_id) do
      bus = Repo.preload(bus, :device)
      last_seen = Uchukuzi.Tracking.status_of(bus) |> IO.inspect()

      conn
      |> render("bus.json", bus: bus, last_seen: last_seen)
    else
      {_, _} ->
        conn
        |> resp(:bad_request, "Buses have an integer id")

      :error ->
        conn
        |> resp(:bad_request, "Buses have an integer id")
    end
  end

  def register_device(conn, %{"bus_id" => bus_id, "imei" => imei}) do
    with {:ok, bus} <- School.bus_for(conn.assigns.manager.school_id, bus_id),
         bus <- Repo.preload(bus, :device),
         nil <- Map.get(bus, :device),
         {:ok, _} <- School.register_device(bus, imei) do
      conn
      |> resp(:created, "{}")
    end
  end

  def list_crew_and_buses(conn, _) do
    crew =
      for crewMember <- School.crew_members_for(conn.assigns.manager.school_id) do
        Repo.preload(crewMember, :bus)
      end

    buses =
      for bus <- School.buses_for(conn.assigns.manager.school_id) do
        {Repo.preload(bus, :device), Uchukuzi.Tracking.status_of(bus)}
      end

    conn
    |> put_view(UchukuziInterfaceWeb.RolesView)
    |> render("crew_and_buses.json", crew_members: crew, buses: buses)
  end

  def update_crew_assignments(conn, %{"_json" => changes}) do
    with {:ok, _} <- School.update_crew_assignments(conn.assigns.manager.school_id, changes) do
      list_crew_and_buses(conn, %{})
    end
  end

  def get_crew_member(conn, %{"crew_member_id" => crew_member_id}) do
    with crew_member <- School.crew_member_for(conn.assigns.manager.school_id, crew_member_id) do
      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("crew_member.json", crew_member: crew_member)
    end
  end

  def update_crew_member(conn, %{"crew_member_id" => crew_member_id} = params) do
    with {:ok, crew_member} <-
           School.update_crew_member_for(conn.assigns.manager.school_id, crew_member_id, params) do
      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("crew_member.json", crew_member: crew_member)
    end
  end

  def list_crew_members(conn, _) do
    crew =
      for crewMember <- School.crew_members_for(conn.assigns.manager.school_id) do
        Repo.preload(crewMember, :bus)
      end

    conn
    |> put_view(UchukuziInterfaceWeb.RolesView)
    |> render("crew_members.json", crew_members: crew)
  end

  def create_crew_member(conn, params) do
    with {:ok, crew_member} <- School.create_crew_member(conn.assigns.manager.school_id, params) do
      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("crew_member.json", crew_member: crew_member)
    end
  end
end
