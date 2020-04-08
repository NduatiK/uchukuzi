defmodule Uchukuzi.School.School do
  use Uchukuzi.School.Model

  alias __MODULE__

  schema "schools" do
    field(:name, :string)

    embeds_one(:perimeter, Geofence)

    has_one(:manager, Uchukuzi.Roles.Manager)
    has_many(:buses, Bus, foreign_key: :school_id)
  end

  def new(name, perimeter) do
    %School{}
    |> changeset(%{name: name, perimeter: perimeter})
  end

  def changeset(schema \\ %__MODULE__{}, params) do
    schema
    |> cast(params, [:name])
    |> validate_required([:name])
    |> cast_embed(:perimeter, with: &Geofence.school_changeset/2)
  end

  @spec contains_point?(Uchukuzi.School.School.t(), Uchukuzi.Common.Location.t()) :: boolean
  def contains_point?(%School{} = school, %Location{} = location) do
    Geofence.contains_point?(school.perimeter, location)
  end

  def set_manager(%School{} = school, %Manager{} = manager) do
    school
    # %School{school | manager: manager}
  end

  def remove_manager(%School{} = school, %Manager{} = manager) do
    school
    # if school.manager == manager do
    #   {:ok, %School{school | manager: nil}}
    # end

    # {:error, :wrong_manager}
  end

  def add_assistant(%School{} = school, %Assistant{} = assistant) do
    school
    # %School{school | assistants: [assistant | school.assistants]}
  end

  def remove_assistant(%School{} = school, %Assistant{} = assistant) do
    school
    # %School{school | assistants: Enum.filter(school.assistants, &(&1 != assistant))}
  end

  def add_bus(%School{} = school, %Bus{} = bus) do
    school
    # %School{school | buses: [bus | school.buses]}
  end

  def remove_bus(%School{} = school, %Bus{} = bus) do
    school
    # %School{school | buses: Enum.filter(school.buses, &(&1 != bus))}
  end

  def add_geofence(%School{} = school, %Geofence{} = geofence) do
    school
    # %School{school | geofences: [geofence | school.geofences]}
  end

  def delete_geofence(%School{} = school, %Geofence{} = geofence) do
    school
    # %School{school | geofences: Enum.filter(school.geofences, &(&1 != geofence))}
  end
end
