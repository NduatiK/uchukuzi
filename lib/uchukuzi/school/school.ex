defmodule Uchukuzi.School.School do
  alias __MODULE__
  alias Uchukuzi.Common.Location
  alias Uchukuzi.Roles.Manager
  alias Uchukuzi.Common.Geofence

  @enforce_keys [:name, :perimeter, :managers, :assistants]
  defstruct [:name, :perimeter, :managers, :assistants]

  def new(name, %Geofence{type: :school} = perimeter) do
    %School{name: name, perimeter: perimeter, assistants: [], managers: []}
  end

  @spec contains_point?(Uchukuzi.School.School.t(), Uchukuzi.Common.Location.t()) :: boolean
  def contains_point?(%School{} = school, %Location{} = location) do
    Geofence.contains_point?(school.perimeter, location)
  end

  def setManager(%School{} = school, %Manager{} = manager) do
    %School{school | managers: [manager | school.managers]}
  end

  def removeManager(%School{} = school, %Manager{} = manager) do
    %School{school | managers: Enum.filter(school.managers, &(&1 != manager))}
  end
end
