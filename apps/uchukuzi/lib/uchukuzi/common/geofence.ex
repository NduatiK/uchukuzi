defmodule Uchukuzi.Common.Geofence do
  use Uchukuzi.School.Model

  @primary_key false
  embedded_schema do
    field(:type, :string)
    embeds_many(:perimeter, Location)
    embeds_one(:center, Location)
    field(:radius, :float)
  end

  def school_changeset(schema \\ %__MODULE__{}, %{radius: _radius, center: _center} = params) do
    params = Map.put(params, :type, "school")

    schema
    |> cast(params, [:type, :radius])
    |> validate_required([:type, :radius])
    |> cast_embed(:center, with: &Location.changeset/2)
  end

  @spec contains_point?(Uchukuzi.Common.Geofence.t(), Uchukuzi.Common.Location.t()) :: boolean
  def contains_point?(%Geofence{type: "school"} = geofence, %Location{} = location) do
    # The school radius is extended to capture arrival points as early as possible
    Location.distance_between(geofence.center, location) <= geofence.radius + 10
  end

  def contains_point?(%Geofence{} = geofence, %Location{} = location) do
    perimeter =
      geofence.perimeter
      |> Enum.map(&Location.to_coord/1)
      |> to_polygon()

    location =
      location
      |> to_geo_point

    location_env = location |> Envelope.from_geo()

    perimeter_env = perimeter |> Envelope.from_geo()

    Envelope.intersects?(perimeter_env, location_env) and Topo.intersects?(perimeter, location)
  end

  defp to_polygon(points), do: %Geo.Polygon{coordinates: [points]}

  defp to_geo_point(%Location{} = location),
    do: %Geo.Point{coordinates: {location.lng, location.lat}}
end
