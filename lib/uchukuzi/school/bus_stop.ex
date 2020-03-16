defmodule Uchukuzi.School.BusStop do
  @moduledoc """
  A `bus stop` is the location at which a bus picks
  and drops some of the students for a given `route`
  """
  alias __MODULE__
  alias Uchukuzi.Location
  alias Uchukuzi.School.Route

  @enforce_keys [:location, :route]
  defstruct [:location, :route]

  def new(%Location{} = location, %Route{} = route) do
    %BusStop{location: location, route: route}
  end

  # def add_student(%BusStop{} = stop, %Student{} = student) do
  # end
end
