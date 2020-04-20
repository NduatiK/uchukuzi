defmodule Uchukuzi.Common.Location do
  alias __MODULE__

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:lat, :float)
    field(:lng, :float)
  end

  # def new_ecto(lng, lat) do
  #   %Location{}
  #   |> changeset(%{lng: lng, lat: lat})
  # end

  def new(lng, lat) do
    if lng >= -180 and lng <= 180 and lat >= -90 and lat <= 90 do
      {:ok, %Location{lng: lng, lat: lat}}
    else
      :error
    end
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:lat, :lng])
    |> validate_required([:lat, :lng])
    |> validate_lat()
    |> validate_lng()
  end

  defp validate_lat(changeset) do
    changeset
    |> validate_number(:lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
  end

  defp validate_lng(changeset) do
    changeset
    |> validate_number(:lng, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
  end

  def is_location(%Location{}), do: true
  def is_location(_), do: false

  def distance_between(%Location{} = loc1, %Location{} = loc2) do
    [loc1, loc2]
    |> Enum.map(&{&1.lng, &1.lat})
    |> Distance.GreatCircle.distance()
  end

  def to_coord(%Location{} = loc) do
    {loc.lng, loc.lat}
  end

  @doc """
  Adapted from  https://github.com/yltsrc/geocalc and https://www.igismap.com/formula-to-find-bearing-or-heading-angle-between-two-points-latitude-longitude/
  """
  @pi :math.pi()

  def bearing(%Location{} = loc_1, %Location{} = loc_2) do
    lat_1 = degrees_to_radians(loc_1.lat)
    lat_2 = degrees_to_radians(loc_2.lat)
    lng_1 = degrees_to_radians(loc_1.lng)
    lng_2 = degrees_to_radians(loc_2.lng)

    x = :math.sin(lng_2 - lng_1) * :math.cos(lat_2)

    y =
      :math.cos(lat_1) * :math.sin(lat_2) -
        :math.sin(lat_1) * :math.cos(lat_2) * :math.cos(lng_2 - lng_1)

    :math.atan2(x, y) * 180 / @pi
  end

  def degrees_to_radians(degrees) do
    normalize_degrees(degrees) * @pi / 180
  end

  defp normalize_degrees(degrees) when degrees < -180 do
    normalize_degrees(degrees + 2 * 180)
  end

  defp normalize_degrees(degrees) when degrees > 180 do
    normalize_degrees(degrees - 2 * 180)
  end

  defp normalize_degrees(degrees) do
    degrees
  end
end