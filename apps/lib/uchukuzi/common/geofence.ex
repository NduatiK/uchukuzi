defmodule Uchukuzi.Common.Geofence do
  use Uchukuzi.School.Model

  import Uchukuzi.Common.Location, only: [is_location: 1]

  @types ["school", "stay_inside", "never_enter"]

  # @enforce_keys [:type]
  # defstruct [:type, :perimeter, :center, :radius]
  @primary_key false
  embedded_schema do
    field(:type, :string)
    embeds_many(:perimeter, Location)
    embeds_one(:center, Location)
    field(:radius, :float)
  end

  def school_changeset(schema \\ %__MODULE__{}, params),
    do: changeset(schema, Map.put(params, :type, "school"))

  def changeset(schema \\ %__MODULE__{}, params)

  def changeset(schema, %{type: _type, radius: _radius, center: _center} = params) do
    schema
    |> cast(params, [:type, :radius])
    |> validate_required([:type, :radius])
    |> cast_embed(:center, with: &Location.changeset/2)
  end

  def changeset(schema, %{type: _type, perimeter: _perimeter} = params) do
    schema
    |> cast(params, [:type])
    |> validate_required([:type])
    |> cast_embed(:perimeter, with: &Location.changeset/2)
  end

  # def put_pass_hash(changeset) do
  #   case changeset do
  #     %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
  #       put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(pass))

  #     _ ->
  #       changeset
  #   end
  # end

  def new_school_fence(%{lat: _lat, lng: _lng} = center, radius)
      when is_number(radius) do
    %Geofence{}
    |> changeset(%{type: "school", center: center, radius: radius})
  end

  def new_inside(perimeter), do: new("stay_inside", perimeter)

  def new_stay_outside(perimeter), do: new("never_enter", perimeter)

  defp new(type, perimeter) when is_list(perimeter) when type in @types do
    %Geofence{}
    |> changeset(%{type: type, perimeter: perimeter})

    # with true <- Enum.all?(perimeter, &is_location/1) do
    #   {:ok, %Geofence{type: type, perimeter: perimeter}}
    # else
    #   _ ->
    #     {:error, "The perimeter must be made up of location objects"}
    # end
  end

  def contains_point?(%Geofence{type: "school"} = geofence, %Location{} = location) do
    Distance.GreatCircle.distance(Location.to_coord(geofence.center), Location.to_coord(location)) <=
      geofence.radius
  end

  @spec contains_point?(Uchukuzi.Common.Geofence.t(), Uchukuzi.Common.Location.t()) :: boolean
  def contains_point?(%Geofence{} = geofence, %Location{} = location) do
    perimeter_points =
      geofence.perimeter
      |> Enum.map(fn point ->
        Location.to_coord(point)
      end)

    perimeter = %Geo.Polygon{coordinates: [perimeter_points]}

    perimeter_env =
      perimeter
      |> Envelope.from_geo()

    location = %Geo.Point{coordinates: {location.lng, location.lat}}

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
