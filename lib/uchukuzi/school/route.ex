defmodule Uchukuzi.School.Route do
  @moduledoc """
  The school defined path that a bus is expected to
  follow in order to pick and drop students
  """
  alias __MODULE__
  alias Uchukuzi.School.BusStop
  import Uchukuzi.Common.Location, only: [is_location: 1]

  @enforce_keys [:name, :locations]
  defstruct [:name, :locations, :stops]

  def new(name, locations) when is_list(locations) do
    with true <- Enum.all?(locations, &is_location/1) do
      {:ok, %Route{name: name, locations: locations}}
    else
      _ ->
        {:error, "Locations must be location objects"}
    end
  end

  def add_stop(%Route{} = route, %BusStop{} = stop) do
    %Route{route | stops: [stop | route.stops]}
  end
end
