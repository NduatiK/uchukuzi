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
      |> Manager.registration_changeset(manager)
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

  def get_school(school_id),
    do: Repo.get(School, school_id)

  def crew_member_for(school_id, crew_member_id) do
    CrewMember
    |> where(school_id: ^school_id, id: ^crew_member_id)
    |> Repo.one()
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

  # ********* BUS *********

  def create_bus(school_id, bus_params) do
    bus_params
    |> Map.put("school_id", school_id)
    |> Bus.new()
    |> Repo.insert()
  end

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
