defmodule Uchukuzi.Location do
  @moduledoc """
  A longitud-
  """
  alias __MODULE__

  @enforce_keys [:lat, :lon]
  defstruct [:lat, :lon]

  def new(lat, lon) when -90 <= lat and lat <= 90 and -180 <= lon and lon <= 180 do
    {:ok, %Location{lat: lat, lon: lon}}
  end

  def is_location(%Location{}), do: true
  def is_location(_), do: false
end
