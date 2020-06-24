defmodule Uchukuzi.Common.Geofence do
  use Uchukuzi.School.Model

  @types ["school", "stay_inside", "never_enter"]

  @primary_key false
  embedded_schema do
    field(:type, :string)
    embeds_many(:perimeter, Location)
    embeds_one(:center, Location)
    field(:radius, :float)
  end

  def school_changeset(schema \\ %__MODULE__{}, params),
    do: changeset(schema, Map.put(params, :type, "school"))

  defp changeset(schema \\ %__MODULE__{}, params)

  defp changeset(schema, %{type: _type, radius: _radius, center: _center} = params) do
    schema
    |> cast(params, [:type, :radius])
    |> validate_required([:type, :radius])
    |> cast_embed(:center, with: &Location.changeset/2)
  end

  defp changeset(schema, %{type: _type, perimeter: _perimeter} = params) do
    schema
    |> cast(params, [:type])
    |> validate_required([:type])
    |> cast_embed(:perimeter, with: &Location.changeset/2)
  end

  defp new(type, perimeter) when is_list(perimeter) when type in @types do
    %Geofence{}
    |> changeset(%{type: type, perimeter: perimeter})
    end

  @spec contains_point?(Uchukuzi.Common.Geofence.t(), Uchukuzi.Common.Location.t()) :: boolean
  def contains_point?(%Geofence{type: "school"} = geofence, %Location{} = location) do
    # The school radius is extended to capture arrival points as early as possible
    Location.distance_between(geofence.center, location) <= (geofence.radius + 10)
  end

  def contains_point?(%Geofence{} = geofence, %Location{} = location) do
    perimeter =
      geofence.perimeter
      |> Enum.map(&Location.to_coord\1)
      |> to_polygon()

    location = location
      |> to_geo_point

    location_env =
      location |> Envelope.from_geo()

    perimeter_env =
        perimeter |> Envelope.from_geo()

    if Envelope.intersects?(perimeter_env , location_env) do
      Topo.intersects?(perimeter, location)
    else
      false
    end
  end

  defp to_polygon(points), do %Geo.Polygon{coordinates: [points]}
  defp to_geo_point(Location{} = location), do %Geo.Point{coordinates: {location.lng, location.lat}}
end
