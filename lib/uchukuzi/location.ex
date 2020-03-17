defmodule Uchukuzi.Location do
  @moduledoc """
  A longitud-
  """
  alias __MODULE__

  @enforce_keys [:lon, :lat]
  defstruct [:lon, :lat]

  def new(lat, lon) when -90 <= lat and lat <= 90 and -180 <= lon and lon <= 180 do
    {:ok, %Location{lon: lon, lat: lat}}
  end

  def is_location(%Location{}), do: true
  def is_location(_), do: false

  def distance_between(%Location{} = loc1, %Location{} = loc2) do
    [loc1, loc2]
    |> Enum.map(&{&1.lon, &1.lat})
    |> Distance.GreatCircle.distance()
  end
end
