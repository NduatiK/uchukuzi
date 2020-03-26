defmodule Uchukuzi.School.School do
  use Uchukuzi.School.Model

  alias __MODULE__

  @enforce_keys [:name, :perimeter, :manager]
  defstruct [
    :name,
    :perimeter,
    :manager,
    assistants: [],
    buses: [],
    households: [],
    geofences: []
  ]

  def new(name, %Geofence{type: :school} = perimeter) do
    %School{name: name, perimeter: perimeter, manager: nil}
  end

  @spec contains_point?(Uchukuzi.School.School.t(), Uchukuzi.Common.Location.t()) :: boolean
  def contains_point?(%School{} = school, %Location{} = location) do
    Geofence.contains_point?(school.perimeter, location)
  end

  def set_manager(%School{} = school, %Manager{} = manager) do
    %School{school | manager: manager}
  end

  def remove_manager(%School{} = school, %Manager{} = manager) do
    if school.manager == manager do
      {:ok, %School{school | manager: nil}}
    end

    {:error, :wrong_manager}
  end

  def add_assistant(%School{} = school, %Assistant{} = assistant) do
    %School{school | assistants: [assistant | school.assistants]}
  end

  def remove_assistant(%School{} = school, %Assistant{} = assistant) do
    %School{school | assistants: Enum.filter(school.assistants, &(&1 != assistant))}
  end

  def add_bus(%School{} = school, %Bus{} = bus) do
    %School{school | buses: [bus | school.buses]}
  end

  def remove_bus(%School{} = school, %Bus{} = bus) do
    %School{school | buses: Enum.filter(school.buses, &(&1 != bus))}
  end

  def add_geofence(%School{} = school, %Geofence{} = geofence) do
    %School{school | geofences: [geofence | school.geofences]}
  end

  def delete_geofence(%School{} = school, %Geofence{} = geofence) do
    %School{school | geofences: Enum.filter(school.geofences, &(&1 != geofence))}
  end
end
