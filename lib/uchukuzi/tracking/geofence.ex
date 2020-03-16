defmodule Uchukuzi.Tracking.Geofence do
  alias __MODULE__
  import Uchukuzi.Location, only: [is_location: 1]
  alias Uchukuzi.Location

  @types [:school, :stay_inside, :never_enter]

  @enforce_keys [:type, :perimeter]
  defstruct [:type, :perimeter]

  def new(type, perimeter) when is_list(perimeter) when type in @types do
    with true <- Enum.all?(perimeter, &is_location/1) do
      {:ok, %Geofence{type: type, perimeter: perimeter}}
    else
      _ ->
        {:error, "The perimeter must be made up of location objects"}
    end
  end

  @spec contains_point?(Uchukuzi.Tracking.Geofence.t(), Uchukuzi.Location.t()) :: boolean
  def contains_point?(%Geofence{} = geofence, %Location{} = location) do
    perimeter_points =
      geofence.perimeter
      |> Enum.map(fn point ->
        {point.lon, point.lat}
        point
      end)

    perimeter = %Geo.Polygon{coordinates: perimeter_points}

    perimeter_env =
      perimeter
      |> Envelope.from_geo()

    location = %Geo.Point{coordinates: {location.lon, location.lat}, srid: nil}

    location_env =
      location
      |> Envelope.from_geo()

    case Envelope.intersects?(perimeter_env, location_env) do
      true ->
        Topo.intersects?(perimeter, location)

      false ->
        false
    end
  end
end
