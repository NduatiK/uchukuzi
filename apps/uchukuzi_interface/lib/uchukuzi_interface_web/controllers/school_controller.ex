defmodule UchukuziInterfaceWeb.SchoolController do
  use UchukuziInterfaceWeb, :controller

  use Uchukuzi.Roles.Model

  alias Uchukuzi.School
  action_fallback(UchukuziInterfaceWeb.FallbackController)
  alias UchukuziInterfaceWeb.Email.{Email, Mailer}

  def action(conn, _) do
    arg_list =
      with :no_manager <- Map.get(conn.assigns, :manager, :no_manager) do
        with :no_assistant <- Map.get(conn.assigns, :assistant, :no_assistant) do
          with :no_household <- Map.get(conn.assigns, :household, :no_household) do
            [conn, conn.params]
          else
            customer ->
              [conn, conn.params, customer]
          end
        else
          assistant ->
            [conn, conn.params, assistant.school_id]
        end
      else
        manager ->
          [conn, conn.params, manager.school_id]
      end

    apply(__MODULE__, action_name(conn), arg_list)
  end

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
         {:ok, %{"manager" => manager, "school" => _school}} <-
           School.create_school(school, manager_params) do
      manager = Repo.preload(manager, :school)

      token = ManagerAuth.sign(manager)

      Email.send_token_email_to(manager, token)
      |> Mailer.deliver_now()

      conn
      |> put_status(:created)
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("manager.json", manager: manager, token: token)
    end
  end

  def school_details(conn, _params, school_id) do
    with school when not is_nil(school) <- School.get_school(school_id) do
      conn
      |> put_status(200)
      |> render("school.json", school: school)
    end
  end

  def edit_school_details(conn, params, school_id) do
    location =
      with lat when is_number(lat) <- Map.get(params, "lat"),
           lng when is_number(lat) <- Map.get(params, "lng"),
           {:ok, location} <- Location.new(lng, lat) do
        location
      else
        _ -> nil
      end

    with {:ok, school} <-
           School.update_school_details(
             school_id,
             Map.put(params, "location", location)
           ) do
      conn
      |> put_status(200)
      |> render("school.json", school: school)
    end
  end

  def edit_school_location(
        conn,
        %{
          "location" => %{
            "lng" => lng,
            "lat" => lat
          }
        } = params,
        school_id
      )
      when is_number(lng) and is_number(lat) do
    with {:ok, location} <- Location.new(lng, lat),
         {:ok, school} <-
           School.update_location(school_id, location, Map.get(params, "radius")) do
      conn
      |> put_status(200)
      |> render("school.json", school: school)
    end
  end

  @spec create_houshold(any, map, any) :: any
  def create_houshold(
        conn,
        %{
          "guardian" => guardian_params,
          "students" => students_params,
          "home_location" => home_location_params,
          "route" => route_id
        },
        school_id
      ) do
    with home_location <- %{
           lng: home_location_params["lng"],
           lat: home_location_params["lat"]
         },
         {:ok, %{"guardian" => guardian}} <-
           School.create_household(
             school_id,
             guardian_params,
             students_params,
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

  def update_household(
        conn,
        %{
          "guardian_id" => guardian_id,
          "guardian" => guardian_params,
          "student_edits" => %{"deletes" => deletes, "edits" => edits},
          "home_location" => home_location_params,
          "route" => route_id
        },
        school_id
      ) do
    with home_location <- %{
           lng: home_location_params["lng"],
           lat: home_location_params["lat"]
         },
         {:ok, _} <-
           School.update_household(
             school_id,
             guardian_id,
             guardian_params,
             edits,
             deletes,
             home_location,
             route_id
           ) do
      conn
      |> resp(200, "{}")
    end
  end

  def get_household(conn, %{"guardian_id" => guardian_id}, school_id) do
    with guardian <- School.guardian_for(school_id, guardian_id) do
      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("guardian.json", guardian: guardian)
    end
  end

  def list_households(conn, _, school_id) do
    guardians = School.guardians_for(school_id)

    conn
    |> put_view(UchukuziInterfaceWeb.RolesView)
    |> render("guardians.json", guardians: guardians)
  end

  def get_qr_code(%{query_params: %{"token" => token}} = conn, %{"student_id" => student_id}) do
    conn =
      %{assigns: %{manager: manager}} =
      conn
      |> put_req_header("authorization", "Bearer " <> token)
      |> ManagerAuth.call(conn)

    with student when not is_nil(student) <- School.student_for(manager.school_id, student_id) do
      student = Repo.preload(student, :guardian)

      qr_code =
        """
        {"id": #{student.id}, "pno": "#{student.guardian.phone_number}"}
        """
        |> EQRCode.encode()
        |> EQRCode.png()

      conn
      |> put_resp_content_type("image/png")
      |> send_resp(200, qr_code)

      # conn
      # |> send
    end
  end

  def create_bus(conn, bus_params, school_id) do
    with {:ok, bus} <- School.create_bus(school_id, bus_params) do
      bus = Repo.preload(bus, [:device, :route])

      conn
      |> put_status(:created)
      |> render("bus.json", bus: bus)
    end
  end

  def update_bus(conn, %{"bus_id" => bus_id} = bus_params, school_id) do
    with {:ok, bus} <- School.update_bus(school_id, bus_id, bus_params) do
      bus = Repo.preload(bus, [:device, :route])

      conn
      |> put_status(:created)
      |> render("bus.json", bus: bus)
    end
  end

  def list_buses(conn, _, school_id) do
    buses =
      for bus <- School.buses_for(school_id) do
        last_seen =
          bus
          |> Uchukuzi.Tracking.status_of()

        {Repo.preload(bus, [:device, :performed_repairs]), last_seen}
      end

    conn
    |> render("buses.json", buses: buses)
  end

  def get_bus(conn, %{"bus_id" => bus_id}, school_id) do
    with {:ok, bus} <- School.bus_for(school_id, bus_id) do
      bus = Repo.preload(bus, [:device, :route])

      last_seen =
        bus
        |> Uchukuzi.Tracking.status_of()

      occupied_seats =
        case bus.route do
          nil ->
            0

          route ->
            route
            |> Repo.preload(:students)
            |> Map.get(:students)
            |> Enum.count()
        end

      conn
      |> render("bus.json", bus: bus, last_seen: last_seen, occupied_seats: occupied_seats)
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

  def create_fuel_report(conn, %{"bus_id" => bus_id} = params, school_id) do
    with {:ok, date} <-
           DateTimeParser.parse_datetime(params["date"], assume_time: true),
         params <- Map.put(params, "date", date),
         {:ok, _repair} <- School.create_fuel_report(school_id, bus_id, params) do
      conn
      |> resp(200, "{}")
    end
  end

  def list_fuel_reports(conn, %{"bus_id" => bus_id}, school_id) do
    with {:ok, bus} <- School.bus_for(school_id, bus_id, [:fuel_reports]) do
      fuel_reports = bus.fuel_reports
      numberOfStudents = school_id |> School.student_count_for_bus(bus.route_id)

      conn
      |> render("fuel_reports.json",
        fuel_reports: fuel_reports,
        numberOfStudents: numberOfStudents
      )
    end
  end

  def delete_fuel_report(conn, %{"bus_id" => bus_id, "_json" => reports}, school_id) do
    with {:ok, bus} <- School.bus_for(school_id, bus_id, [:fuel_reports]),
         {:ok, reports} <- valid_report_ids(reports, bus.fuel_reports),
         {_no_of_deletions, nil} <- School.delete_fuel_reports(school_id, bus_id, reports) do
      conn
      |> resp(200, "{}")
    end
  end

  def valid_report_ids(reports, existing_reports) do
    fuel_report_ids = existing_reports |> Enum.map(& &1.id)

    cond do
      not Enum.all?(reports, &is_integer/1) ->
        {:error, "expected ids"}

      not Enum.all?(reports, fn report -> report in fuel_report_ids end) ->
        {:error, "these ids are not yours"}

      true ->
        {:ok, reports}
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
      |> resp(200, "{}")
    end
  end

  def get_crew_member(conn, %{"crew_member_id" => crew_member_id}, school_id) do
    with crew_member <- School.crew_member_for(school_id, crew_member_id) do
      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("crew_member.json", crew_member: crew_member)
    end
  end

  def get_crew_members_for_bus(conn, %{"bus_id" => bus_id}, school_id) do
    with crew_members <- School.crew_members_for_bus(school_id, bus_id) do
      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("crew_members.json", crew_members: crew_members)
    end
  end

  def get_students_onboard(conn, %{"bus_id" => bus_id}, school_id) do
    with {:ok, bus} <- School.bus_for(school_id, bus_id) do
      student_ids = Uchukuzi.Tracking.students_onboard(bus)

      students =
        Uchukuzi.Roles.Student
        |> where([c], c.id in ^student_ids)
        |> Uchukuzi.Repo.all()

      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("students.json", students: students)
    end
  end

  def get_bus_route(conn, %{"bus_id" => bus_id}, school_id) do
    with {:ok, bus} <- School.bus_for(school_id, bus_id) do
      route = Repo.preload(bus, :route).route

      conn
      |> render("route.json", route: route)
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

  def create_route(conn, params, school_id) do
    with {:ok, _route} <- School.create_route(school_id, params) do
      conn
      |> resp(200, "{}")
    end
  end

  def create_route_from_trip(conn, %{"trip_id" => trip_id, "name" => name}, school_id) do
    with {:ok, _route} <-
           School.create_route_from_trip(school_id, trip_id, name) do
      conn
      |> resp(200, "{}")
    end
  end

  def get_route(conn, %{"route_id" => route_id}, school_id) do
    with route when not is_nil(route) <-
           School.get_route(school_id, route_id) do
      conn
      |> render("route.json", route: route)
    else
      _ ->
        {:error, :not_found}
    end
  end

  def update_route(conn, %{"route_id" => route_id} = params, school_id) do
    with {:ok, _route} <-
           School.update_route(school_id, route_id, params) do
      conn
      |> resp(200, "{}")
    end
  end

  def delete_route(conn, %{"route_id" => route_id}, school_id) do
    with {:ok, _route} <-
           School.delete_route(school_id, route_id) do
      conn
      |> resp(200, "{}")
    end
  end

  def copy_trip(conn, %{"route_id" => route_id, "trip_id" => trip_id}, school_id) do
    with {:ok, _route} <-
           School.update_route_from_trip(school_id, route_id, trip_id) do
      conn
      |> resp(200, "{}")
    end
  end

  @spec list_routes(Plug.Conn.t(), any, any) :: Plug.Conn.t()
  def list_routes(conn, _, school_id) do
    routes = School.routes_for(school_id)

    conn
    |> render("routes.json", routes: routes)
  end

  def list_routes_available_for_bus(conn, _, school_id) do
    routes = School.routes_available_for(school_id, Map.get(conn.query_params, "bus_id"))

    conn
    |> render("simple_routes.json", routes: routes)
  end

  def route_for_assistant(
        %{query_params: %{"travel_time" => travel_time}} = conn,
        _,
        school_id
      ) do
    assistant_id = conn.assigns.assistant.id

    with {:ok, data} <- School.route_for_assistant(school_id, assistant_id, travel_time) do
      conn
      |> render("route_for_assistant.json", data: data)
    end
  end

  def student_boarded(conn, %{"student_id" => student_id}, school_id) do
    with :ok <- School.student_boarded(school_id, conn.assigns.assistant, student_id) do
      conn
      |> resp(200, "{}")
    end
  end

  def student_exited(conn, %{"student_id" => student_id}, school_id) do
    with :ok <- School.student_exited(school_id, conn.assigns.assistant, student_id) do
      conn
      |> resp(200, "{}")
    end
  end

  def data_for_household(conn, _, %Guardian{} = guardian) do
    guardian = Repo.preload(guardian, :students)

    students =
      guardian.students
      |> preloadData()

    conn
    |> put_view(UchukuziInterfaceWeb.RolesView)
    |> render("customer_data.json",
      students: students
    )
  end

  def data_for_household(conn, _, %Student{} = student) do
    students =
      [student]
      |> preloadData()

    conn
    |> put_view(UchukuziInterfaceWeb.RolesView)
    |> render("customer_data.json",
      students: students
    )
  end

  def preloadData(students) do
    for student <- students do
      with student <- Repo.preload(student, [:route, :school]),
           bus <- Repo.preload(student.route, :bus).bus do
        {student, bus}
      end
    end
  end

  def list_trips(conn, %{"bus_id" => bus_id}, school_id) do
    with {bus_id, ""} <- Integer.parse(bus_id),
         {:ok, bus} <- School.bus_for(school_id, bus_id) do
      trips = Repo.preload(bus, :trips).trips

      conn
      |> put_view(UchukuziInterfaceWeb.TrackingView)
      |> render("trips.json", trips: trips)
    end
  end

  def trip_details(conn, %{"trip_id" => trip_id}, school_id) do
    with {trip_id, ""} <- Integer.parse(trip_id),
         trip <- Uchukuzi.Tracking.trip_for(school_id, trip_id) do
      trip = Repo.preload(trip, :report_collection)

      conn
      |> put_view(UchukuziInterfaceWeb.TrackingView)
      |> render("trip.json", trip: trip)
    end
  end

  def ongoing_trip_details(conn, %{"bus_id" => bus_id}, school_id) do
    with {:ok, bus} <- School.bus_for(school_id, bus_id) do
      trip = Uchukuzi.Tracking.ongoing_trip_for(bus)

      conn
      |> put_view(UchukuziInterfaceWeb.TrackingView)
      |> render("trip.json", trip: trip)
    end
  end
end
