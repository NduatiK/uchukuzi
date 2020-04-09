defmodule Uchukuzi.School do
  @moduledoc """
  Module through which managers can modify school records.

  Provides access to school, bus and household data
  """

  alias Ecto.Multi

  use Uchukuzi.School.Model
  use Uchukuzi.Roles.Model

  # ********* SCHOOL *********

  def create_school(school_changeset, manager) do
    Multi.new()
    |> Multi.insert(:school, school_changeset)
    |> Multi.insert(:manager, fn %{school: school} ->
      Ecto.build_assoc(school, :manager)
      |> Manager.changeset(manager)
    end)
    |> Repo.transaction()
  end

  def buses_for(school_id) do
    Repo.get(School, school_id)
    |> Repo.preload(:buses)
    |> Map.get(:buses)
  end

  def bus_for(school_id, bus_id) do
    with bus when not is_nil(bus) <- Repo.get_by(Bus, school_id: school_id, id: bus_id) do
      {:ok, bus}
    else
      nil -> {:error, :not_found}
    end
  end

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

  # def add_assistant(%School{} = school, %Assistant{} = assistant) do
  #   School.add_assistant(school, assistant)
  # end

  # def remove_assistant(%School{} = school, %Assistant{} = assistant) do
  #   School.remove_assistant(school, assistant)
  # end

  # def add_bus(%School{} = school, %Bus{} = bus) do
  #   School.add_bus(school, bus)
  # end

  # def remove_bus(%School{} = school, %Bus{} = bus) do
  #   School.remove_bus(school, bus)
  # end

  # def add_geofence_to_school(%School{} = school, %Geofence{} = geofence) do
  #   School.add_geofence(school, geofence)
  # end

  # def delete_geofence_from_school(%School{} = school, %Geofence{} = geofence) do
  #   School.delete_geofence(school, geofence)
  # end

  def get_school(school_id),
    do: Repo.get(School, school_id)

  # ********* BUS *********

  def create_bus(school_id, bus_params) do
    bus_params
    |> Map.put("school_id", school_id)
    |> Bus.new()
    |> Repo.insert()
  end

  # def assign_assistant_to_bus(%Bus{} = bus, %Assistant{} = assistant) do
  #   Bus.assign_assistant(bus, assistant)
  # end

  # def remove_assistant_from_bus(%Bus{} = bus, %Assistant{} = assistant) do
  #   Bus.assign_assistant(bus, assistant)
  # end

  # def set_device(%Bus{} = bus, %Device{} = device) do
  #   Bus.set_device(bus, device)
  # end

  # def remove_device(%Bus{} = bus, %Device{} = device) do
  #   Bus.remove_device(bus, device)
  # end

  # def create_fuel_record(%Bus{} = bus, %FuelRecord{} = record) do
  #   Bus.add_fuel_record(bus, record)
  # end

  # def delete_fuel_record(%Bus{} = bus, %FuelRecord{} = record) do
  #   Bus.delete_fuel_record(bus, record)
  # end

  # def schedule_maintenance(%Bus{} = bus, %ScheduledRepair{} = schedule) do
  #   Bus.schedule_maintenance(bus, schedule)
  # end

  # def unschedule_maintenance(%Bus{} = bus, %ScheduledRepair{} = schedule) do
  #   Bus.unschedule_maintenance(bus, schedule)
  # end

  # def add_maintenance_record(%Bus{} = bus, %PerformedRepair{} = record) do
  #   Bus.add_maintenance_record(bus, record)
  # end

  # def delete_maintenance_record(%Bus{} = bus, %PerformedRepair{} = record) do
  #   Bus.delete_maintenance_record(bus, record)
  # end

  # ********* Routes *********

  def create_route(school_id, name, path) do
    %{
      school_id: school_id,
      name: name,
      path: path
    }
    |> Route.changeset()
    |> Repo.insert()
  end


  # ********* HOUSEHOLDS *********
  def create_household(
        school_id,
        guardian_params,
        students_params,
        pickup_location,
        home_location,
        route_id
      ) do
    Multi.new()
    # Build Guardian
    |> Multi.insert(:guardian, Guardian.changeset(%Guardian{}, guardian_params))
    # Recursively build student
    |> Multi.merge(fn %{guardian: guardian} ->
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
            pickup_location,
            home_location,
            school_id,
            route_id
          )
        )
      end)
    end)
    |> Repo.transaction()
  end

  def guardians_for(school_id) do
    Repo.all(
      from(g in Guardian,
        join: s in assoc(g, :students),
        where: s.school_id == ^school_id,
        preload: [students: s]
      )
    )

    # Guardian
    # |> join(:left, [g], s in Student, on: s.guardian_id == g.id and s.school_id == ^school_id)
    # |> select([g, s], {g, s})
    # |> Repo.all()
    # |> IO.inspect
  end
end
