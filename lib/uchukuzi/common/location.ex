defmodule Uchukuzi.Common.Location do
  # @moduledoc """
  # A longitud-
  # """

  # @enforce_keys [:lon, :lat]
  # defstruct [:lon, :lat]

  # def new(lon, lat) when -90 <= lat and lat <= 90 and -180 <= lon and lon <= 180 do
  #   {:ok, %Location{lon: lon, lat: lat}}
  # end

  # def is_location(%Location{}), do: true
  # def is_location(_), do: false

  # def distance_between(%Location{} = loc1, %Location{} = loc2) do
  #   [loc1, loc2]
  #   |> Enum.map(&{&1.lon, &1.lat})
  #   |> Distance.GreatCircle.distance()
  # end

  # def to_coord(%Location{} = loc) do
  #   {loc.lon, loc.lat}
  # end

  alias __MODULE__

  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:latitude, :float)
    field(:longitude, :float)
  end

  def new(lon, lat) do
    %Location{}
    |> changeset(%{longitude: lon, latitude: lat})
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:latitude, :longitude])
    |> validate_required([:latitude, :longitude])
    |> validate_latitude()
    |> validate_longitude()
  end

  defp validate_latitude(changeset) do
    changeset
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
  end

  defp validate_longitude(changeset) do
    changeset
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
  end

  def is_location(%Location{}), do: true
  def is_location(_), do: false

  def distance_between(%Location{} = loc1, %Location{} = loc2) do
    [loc1, loc2]
    |> Enum.map(&{&1.lon, &1.lat})
    |> Distance.GreatCircle.distance()
  end

  def to_coord(%Location{} = loc) do
    {loc.lon, loc.lat}
  end
end
