defmodule Uchukuzi.School do
  @moduledoc """
  Module through which managers can modify school records.

  Provides access to school, bus and household data
  """

  alias Ecto.Multi

  use Uchukuzi.School.Model
  use Uchukuzi.Roles.Model
  alias Uchukuzi.Tracking.BusServer

  # ********* SCHOOL *********

  def create_school(school_changeset, manager) do
    Multi.new()
    |> Multi.insert("school", school_changeset)
    |> Multi.insert("manager", fn %{"school" => school} ->
      Ecto.build_assoc(school, :manager)
      |> Manager.registration_changeset(manager)
    end)
    |> Repo.transaction()
  end

  def update_school_details(school_id, params) do
    school =
      School
      |> where(id: ^school_id)
      |> Repo.one()

    map_if_present = (fn
      p, params, paramName, internalName   ->
        cond do
          value = Map.get(params, paramName)  ->
            Map.put(p, internalName, value)
          true ->
            p
        end
    end)



    perimeter =
      school.perimeter
      |>map_if_present.(params, "location", :center)
      |>map_if_present.(params, "radius", :radius)

      change_if_present = (fn
                 p, params, paramName, internalName   ->
            cond do
              value = Map.get(params, paramName)  ->
                change(p, [{internalName, value}])
              true ->
                p
            end
      end)

    school
    |> change(perimeter: perimeter)
    |> change_if_present.(params, "name", :name)
    |> change_if_present.(params, "deviation_radius", :deviation_radius)
    |> Repo.update()
    |> inform_buses_of_school_update()
  end

  def inform_buses_of_school_update({:ok, school}), do:
    {:ok, inform_buses_of_school_update(school)}

  def inform_buses_of_school_update(%School{} = school) do
    Repo.all(
      from(b in Bus,
        where: b.school_id == ^school.id,
      )
    )
    |> Enum.map(& &1.id)
    |> Enum.map(&Uchukuzi.Tracking.TripTracker.update_school/1)

    school
  end

  def inform_buses_of_school_update(pass), do: pass


  def update_location(school_id, location, radius \\ 50) do
    school =
      School
      |> where(id: ^school_id)
      |> Repo.one()

    perimeter = %{school.perimeter | center: location, radius: radius}

    school
    |> change(perimeter: perimeter)
    |> Repo.update()
  end

  @spec get_school(any) :: any
  def get_school(school_id),
    do: Repo.get(School, school_id)

  # ********* Buses *********
  def buses_for(school_id) do
    Repo.all(
      from(b in Bus,
        where: b.school_id == ^school_id,
        preload: [:route, :device]
      )
    )
  end

  def bus_for(school_id, bus_id) do
    with bus when not is_nil(bus) <- Repo.get_by(Bus, school_id: school_id, id: bus_id) do
      {:ok, Repo.preload(bus, [:performed_repairs])}
    else
      nil -> {:error, :not_found}
    end
  end

  def create_bus(school_id, bus_params) do
    bus_params
    |> Map.put("school_id", school_id)
    |> Bus.new()
    |> Repo.insert()
  end

  def update_bus(school_id, bus_id, params) do
    with bus when not is_nil(bus) <- Repo.get_by(Bus, school_id: school_id, id: bus_id) do
      bus
      |> Bus.changeset(params)
      |> Repo.update()
    else
      nil -> {:error, :not_found}
    end
  end

  def create_performed_repair(school_id, bus_id, params) do
    with {:ok, bus} <- bus_for(school_id, bus_id) do
      params
      |> Enum.reduce(Multi.new(), fn params, multi ->
        multi
        |> Multi.run(
          Integer.to_string(params["browser_id"]),
          fn _repo, _ ->
            params
            |> Map.put("bus_id", bus.id)
            |> PerformedRepair.changeset()
            |> Repo.insert()
          end
        )
      end)
      |> Repo.transaction()
    end
  end

  def create_fuel_report(school_id, bus_id, params) do
    with {:ok, bus} <- bus_for(school_id, bus_id) do
      distance_travelled =
        bus
        |> Bus.distance_travelled_before(params["date"])

      params
      |> Map.put("distance_travelled", distance_travelled)
      |> FuelReport.changeset()
      |> Repo.insert()
    end
  end

  def fuel_reports(school_id, bus_id) do
    Repo.all(
      from(r in FuelReport,
        left_join: b in assoc(r, :bus),
        where: b.school_id == ^school_id and b.id == ^bus_id
      )
    )
  end

  # ********* Devices *********
  def register_device(bus, imei) do
    %{imei: imei, bus_id: bus.id}
    |> Device.new()
    |> Repo.insert()
  end

  def device_with_imei(imei) do
    with device when not is_nil(device) <- Repo.get_by(Device, imei: imei) do
      {:ok, device}
    else
      nil -> {:error, :not_found}
    end
  end

  def crew_member_for(school_id, crew_member_id) do
    CrewMember
    |> where(school_id: ^school_id, id: ^crew_member_id)
    |> Repo.one()
  end

  def crew_members_for_bus(school_id, bus_id) do
    CrewMember
    |> where(school_id: ^school_id, bus_id: ^bus_id)
    |> Repo.all()
  end

  def update_crew_member_for(school_id, crew_member_id, params) do
    CrewMember
    |> where(school_id: ^school_id, id: ^crew_member_id)
    |> Repo.one()
    |> CrewMember.changeset(params)
    |> Repo.update()
  end

  def crew_members_for(school_id) do
    CrewMember
    |> where(school_id: ^school_id)
    |> Repo.all()
  end

  def create_crew_member(school_id, params) do
    params
    |> Map.put("school_id", school_id)
    |> CrewMember.changeset()
    |> Repo.insert()
  end

  def update_crew_assignments(school_id, params) do
    Multi.new()
    |> Multi.merge(fn _ ->
      params
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {param, idx}, multi ->
        multi
        |> Multi.update(
          "change" <> Integer.to_string(idx),
          if param["change"] == "add" do
            Repo.get(CrewMember, param["crew_member"], school_id: school_id)
            |> change(bus_id: param["bus"])
          else
            Repo.get_by(CrewMember, id: param["crew_member"], school_id: school_id)
            |> change(bus_id: nil)
          end
        )
      end)
    end)
    |> Repo.transaction()
  end

  # ********* Routes *********

  def route_for_assistant(school_id, assistant_id, travel_time) do
    with crew_member when not is_nil(crew_member) <-
           CrewMember |> where(school_id: ^school_id, id: ^assistant_id) |> Uchukuzi.Repo.one(),
         bus_id when not is_nil(bus_id) <- crew_member.bus_id,
         crew_member <- crew_member |> Repo.preload(:bus),
         route_id when not is_nil(route_id) <- crew_member.bus.route_id,
         bus <- crew_member.bus |> Repo.preload(:route) do
      students =
        Repo.all(
          from(s in Student,
            left_join: g in assoc(s, :guardian),
            where:
              s.route_id == ^bus.route.id and
                (s.travel_time == ^travel_time or s.travel_time == "two-way"),
            preload: [guardian: g],
            select: [s, g.phone_number, g.name]
          )
        )

      {:ok,
       %{
         crew_member: crew_member,
         bus: bus,
         students: students,
         route: bus.route
       }}
    else
      nil ->
        {:error, :not_found}
    end
  end

  def student_boarded(school_id, assistant, student_id) do
    with student when not is_nil(student) <-
           Student |> where(school_id: ^school_id, id: ^student_id) |> Uchukuzi.Repo.one(),
         bus_id when not is_nil(bus_id) <- assistant.bus_id,
         bus <- (assistant |> Repo.preload(:bus)).bus do
      Uchukuzi.Tracking.TripTracker.student_boarded(
        bus,
        Uchukuzi.Tracking.StudentActivity.boarded(student, assistant)
      )
    end
  end

  def student_exited(school_id, assistant, student_id) do
    with student when not is_nil(student) <-
           Student
           |> where(school_id: ^school_id, id: ^student_id)
           |> Uchukuzi.Repo.one(),
         bus_id when not is_nil(bus_id) <- assistant.bus_id,
         bus <- (assistant |> Repo.preload(:bus)).bus do
      Uchukuzi.Tracking.TripTracker.student_exited(
        bus,
        Uchukuzi.Tracking.StudentActivity.exited(student, assistant)
      )
    end
  end

  def routes_for(school_id) do
    Repo.all(
      from(r in Route,
        left_join: b in assoc(r, :bus),
        where: r.school_id == ^school_id,
        preload: [bus: b]
      )
    )
  end

  def routes_available_for(school_id, bus_id) do
    Repo.all(
      from(r in Route,
        left_join: b in assoc(r, :bus),
        where: r.school_id == ^school_id and (is_nil(b) or b.id == ^bus_id),
        preload: [bus: b],
        select: r
      )
    )
  end

  def create_route(school_id, %{"name" => name, "path" => path}) do
    %{
      school_id: school_id,
      name: name,
      path: path
    }
    |> Route.changeset()
    |> Repo.insert()
  end

  def get_route(school_id, route_id) do
    Route
    |> where(school_id: ^school_id, id: ^route_id)
    |> Repo.one()
  end

  def update_route(school_id, route_id, params) do
    Route
    |> where(school_id: ^school_id, id: ^route_id)
    |> Repo.one()
    |> Route.changeset(params)
    |> Repo.update()
  end

  def update_route_from_trip(school_id, route_id, trip_id) do
    with trip <- Uchukuzi.Tracking.trip_for(school_id, trip_id) do
      trip = Repo.preload(trip, :report_collection)

      Route
      |> where(school_id: ^school_id, id: ^route_id)
      |> Repo.one()
      |> change(
        expected_tiles: trip.report_collection.crossed_tiles,
        path:
          trip.report_collection.reports
          |> Enum.map(& &1.location)
      )
      |> Repo.update()
    end
  end

  def create_route_from_trip(school_id, trip_id, name) do
    with trip <- Uchukuzi.Tracking.trip_for(school_id, trip_id) do
      trip = Repo.preload(trip, :report_collection)

      %{
        school_id: school_id,
        name: name
      }
      |> Route.changeset()
      |> change(
        expected_tiles: trip.report_collection.crossed_tiles,
        path:
          trip.report_collection.reports
          |> Enum.map(& &1.location)
      )
      |> Repo.insert()
    end
  end

  def delete_route(school_id, route_id) do
    Route
    |> where(school_id: ^school_id, id: ^route_id)
    |> Repo.one()
    |> Repo.delete()
  end




  # ********* HOUSEHOLDS *********
  def create_household(
        school_id,
        guardian_params,
        students_params,
        home_location,
        route_id
      ) do
    Multi.new()
    # Build Guardian
    |> Multi.insert("guardian", Guardian.changeset(%Guardian{}, guardian_params))
    # Recursively build student
    |> Multi.merge(fn %{"guardian" => guardian} ->
      students_params
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {student_params, idx}, multi ->
        multi
        |> Multi.insert(
          "student" <> Integer.to_string(idx),
          guardian
          |> Ecto.build_assoc(:students)
          |> Student.changeset(
            student_params,
            home_location,
            school_id,
            route_id
          )
        )
      end)
    end)
    |> Repo.transaction()
  end

  def update_household(
        school_id,
        guardian_id,
        guardian_params,
        student_edits,
        student_deletes,
        home_location,
        route_id
      ) do
    matching_id = fn x ->
      fn y ->
        y.id == x
      end
    end

    cond do
      guardian = Uchukuzi.Roles.get_guardian_by(id: guardian_id) ->
        guardian = Repo.preload(guardian, :students)

        Multi.new()
        |> Multi.update("guardian", Guardian.changeset(guardian, guardian_params))
        |> Multi.merge(fn %{"guardian" => guardian} ->
          student_edits
          |> Enum.with_index()
          |> Enum.reduce(Multi.new(), fn {student_edit, idx}, multi ->
            cond do
              student_edit["id"] < 0 ->
                multi
                |> Multi.insert(
                  "student" <> Integer.to_string(idx),
                  guardian
                  |> Ecto.build_assoc(:students)
                  |> Student.changeset(
                    student_edit,
                    home_location,
                    school_id,
                    route_id
                  )
                )

              existing =
                  student_edit["id"] > 0 &&
                    Enum.find(guardian.students, matching_id.(student_edit["id"])) ->
                multi
                |> Multi.update(
                  "student" <> Integer.to_string(idx),
                  existing
                  |> Student.changeset(
                    student_edit,
                    home_location,
                    school_id,
                    route_id
                  )
                )

              true ->
                multi
                |> Multi.error(:error, :not_found)
            end
          end)
        end)
        |> Multi.merge(fn %{"guardian" => guardian} ->
          student_deletes
          |> Enum.with_index()
          |> Enum.reduce(Multi.new(), fn {delete_id, idx}, multi ->
            cond do
              existing = Enum.find(guardian.students, matching_id.(delete_id)) ->
                multi
                |> Ecto.Multi.delete("delete" <> Integer.to_string(idx), existing)

              true ->
                multi
            end
          end)
        end)
        |> Repo.transaction()

      true ->
        {:error, :not_found}
    end
  end

  def guardians_for(school_id) do
    Repo.all(
      from(g in Guardian,
        join: s in assoc(g, :students),
        where: s.school_id == ^school_id,
        preload: [students: s]
      )
    )
  end

  def guardian_for(school_id, guardian_id) do
    Repo.one(
      from(g in Guardian,
        join: s in assoc(g, :students),
        where: s.school_id == ^school_id and g.id == ^guardian_id,
        preload: [students: s]
      )
    )
  end

  def student_for(school_id, student_id) do
    Student
    |> where(school_id: ^school_id, id: ^student_id)
    |> Repo.one()
  end
end
