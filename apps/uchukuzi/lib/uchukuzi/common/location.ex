defmodule Uchukuzi.Common.Location do
  alias __MODULE__

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:lat, :float)
    field(:lng, :float)
  end

  @spec new(any, any) :: :error | {:ok, Uchukuzi.Common.Location.t()}
  def new(lng, lat) do
    if lng >= -180 and lng <= 180 and lat >= -90 and lat <= 90 do
      {:ok, %Location{lng: lng, lat: lat}}
    else
      :error
    end
  end

  def wrapping_new(lng, lat) when lng >= -180 and lng <= 180 and lat >= -90 and lat <= 90 do
    %Location{lng: lng, lat: lat}
  end

  def wrapping_new(lng, lat) do
    lng =
      cond do
        lng > 180 ->
          lng - 360

        lng < -180 ->
          lng + 360

        true ->
          lng
      end

    lat =
      cond do
        lat > 90 ->
          180 - lat

        lng < -90 ->
          -(180 + lat)

        true ->
          lat
      end

    wrapping_new(lng, lat)
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

  @doc """
  The distance between two locations in meters
  """

  def distance_between(%Location{} = loc1, %Location{} = loc2) do
    [loc1, loc2]
    |> Enum.map(&to_coord/1)
    |> Distance.GreatCircle.distance()
  end

  def distance_between({_, _} = loc1, {_, _} = loc2) do
    [loc1, loc2]
    |> Distance.GreatCircle.distance()
  end

  def to_coord(%Location{} = loc) do
    {loc.lng, loc.lat}
  end

  @doc """
  Reference:
  Adapted from  https://github.com/yltsrc/geocalc and
  https://www.igismap.com/formula-to-find-bearing-or-heading-angle-between-two-points-latitude-longitude/
  """
  @pi :math.pi()

  def bearing(%Location{} = from, %Location{} = to) do
    loc_1 = to
    loc_2 = from
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

  defp degrees_to_radians(degrees) do
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
