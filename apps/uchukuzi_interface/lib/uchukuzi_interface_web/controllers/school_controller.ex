defmodule UchukuziInterfaceWeb.SchoolController do
  use UchukuziInterfaceWeb, :controller

  alias Uchukuzi.School
  action_fallback(UchukuziInterfaceWeb.FallbackController)

  def action(conn, _) do
    arg_list =
      with :no_manager <- Map.get(conn.assigns, :manager, :no_manager) do
        [conn, conn.params, nil]
      else
        manager ->
          [conn, conn.params, manager.school_id]
      end

    apply(__MODULE__, action_name(conn), arg_list)
  end

  def create_school(conn, %{"manager" => manager_params, "school" => school_params}, _) do
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

  def create_houshold(
        conn,
        %{
          "guardian" => guardian_params,
          "students" => students_params,
          "pickup_location" => pickup_location_params,
          "home_location" => home_location_params,
          "route" => route_id
        },
        school_id
      ) do
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
             school_id,
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

  def list_households(conn, _, school_id) do
    guardians =
      for guardian <- School.guardians_for(school_id) do
        Repo.preload(guardian, :students)
      end

    conn
    |> put_view(UchukuziInterfaceWeb.RolesView)
    |> render("guardians.json", guardians: guardians)
  end

  def create_bus(conn, bus_params, school_id) do
    with {:ok, bus} <- School.create_bus(school_id, bus_params) do
      bus = Repo.preload(bus, :device)

      conn
      |> put_status(:created)
      |> render("bus.json", bus: bus)
    end
  end

  def list_buses(conn, _, school_id) do
    buses =
      for bus <- School.buses_for(school_id) do
        {Repo.preload(bus, [:device, :performed_repairs]), Uchukuzi.Tracking.status_of(bus)}
      end

    conn
    |> render("buses.json", buses: buses)
  end

  def get_bus(conn, %{"bus_id" => bus_id}, school_id) do
    with {:ok, bus} <- School.bus_for(school_id, bus_id) do
      bus = Repo.preload(bus, :device)
      last_seen = Uchukuzi.Tracking.status_of(bus) |> IO.inspect()

      conn
      |> render("bus.json", bus: bus, last_seen: last_seen)
    end
  end

  def create_performed_repair(conn, %{"bus_id" => bus_id, "_json" => repairs}, school_id) do
    params =
      for repair <- repairs do
        with id when is_integer(id) <- Map.get(repair, "id", :missing_id) do
          repair
          |> Map.delete("id")
          |> Map.put_new("browser_id", id)
        end
      end

    with {:ok, _repair} <- School.create_performed_repair(school_id, bus_id, params) do
      conn
      |> resp(200, "{}")
    end
  end

  # * Devices
  def register_device(conn, %{"bus_id" => bus_id, "imei" => imei}, school_id) do
    with {:ok, bus} <- School.bus_for(school_id, bus_id),
         bus <- Repo.preload(bus, :device),
         nil <- Map.get(bus, :device),
         {:ok, _} <- School.register_device(bus, imei) do
      conn
      |> resp(:created, "{}")
    end
  end

  # * Crew members

  def list_crew_and_buses(conn, _, school_id) do
    crew =
      for crewMember <- School.crew_members_for(school_id) do
        Repo.preload(crewMember, :bus)
      end

    buses =
      for bus <- School.buses_for(school_id) do
        {Repo.preload(bus, :device), Uchukuzi.Tracking.status_of(bus)}
      end

    conn
    |> put_view(UchukuziInterfaceWeb.RolesView)
    |> render("crew_and_buses.json", crew_members: crew, buses: buses)
  end

  def update_crew_assignments(conn, %{"_json" => changes}, school_id) do
    with {:ok, _} <- School.update_crew_assignments(school_id, changes) do
      conn
      |> redirect(to: "/crew_and_buses")
    end
  end

  def get_crew_member(conn, %{"crew_member_id" => crew_member_id}, school_id) do
    with crew_member <- School.crew_member_for(school_id, crew_member_id) do
      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("crew_member.json", crew_member: crew_member)
    end
  end

  def update_crew_member(conn, %{"crew_member_id" => crew_member_id} = params, school_id) do
    with {:ok, crew_member} <-
           School.update_crew_member_for(school_id, crew_member_id, params) do
      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("crew_member.json", crew_member: crew_member)
    end
  end

  def list_crew_members(conn, _, school_id) do
    crew =
      for crewMember <- School.crew_members_for(school_id) do
        Repo.preload(crewMember, :bus)
      end

    conn
    |> put_view(UchukuziInterfaceWeb.RolesView)
    |> render("crew_members.json", crew_members: crew)
  end

  def create_crew_member(conn, params, school_id) do
    with {:ok, crew_member} <- School.create_crew_member(school_id, params) do
      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("crew_member.json", crew_member: crew_member)
    end
  end
end
