defmodule Uchukuzi.Common.Geofence do
  alias __MODULE__
  import Uchukuzi.Common.Location, only: [is_location: 1]
  alias Uchukuzi.Common.Location

  @types [:school, :stay_inside, :never_enter]

  @enforce_keys [:type, :perimeter]
  defstruct [:type, :perimeter]

  @spec new_inside([...]) :: {:error, <<_::392>>} | {:ok, Uchukuzi.Common.Geofence.t()}
  def new_inside(perimeter), do:
    new(:stay_inside, perimeter)

  def new_school_fence(perimeter), do:
    new(:school, perimeter)

  def new_stay_outside(perimeter), do:
    new(:never_enter, perimeter)

  @spec new(atom, [Uchukuzi.Common.Location.t(), ...]) ::
          {:error, any} | {:ok, Uchukuzi.Common.Geofence.t()}
  defp new(type, perimeter) when is_list(perimeter) when type in @types do
    with true <- Enum.all?(perimeter, &is_location/1) do
      {:ok, %Geofence{type: type, perimeter: perimeter}}
    else
      _ ->
        {:error, "The perimeter must be made up of location objects"}
    end
  end

  @spec contains_point?(Uchukuzi.Common.Geofence.t(), Uchukuzi.Common.Location.t()) :: boolean
  def contains_point?(%Geofence{} = geofence, %Location{} = location) do
    perimeter_points =
      geofence.perimeter
      |> Enum.map(fn point ->
        {point.lon, point.lat}
      end)

    perimeter = %Geo.Polygon{coordinates: [perimeter_points]}

    perimeter_env =
      perimeter
      |> Envelope.from_geo()

    location = %Geo.Point{coordinates: {location.lon, location.lat}}

    location_env =
      location
      |> Envelope.from_geo()

    if Envelope.intersects?(perimeter_env, location_env) do
      Topo.intersects?(perimeter, location)
    else
      false
    end
  end
end
