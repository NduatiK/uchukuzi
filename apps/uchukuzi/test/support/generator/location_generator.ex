defmodule UchukuziTest.LocationGenerator do
  use PropCheck
  import PropCheck
  alias Uchukuzi.Common.Location

  @doc """
  A locations generator with a higher likelihood
  of edge cases near the 180/-180° and 90/-90° line
  """
  def edge_locations() do
    let {lng, lat} <- {edge_lng(), edge_lat()} do
      # {:ok, loc1} = Location.new(lng, lat)

      size = 0.0025
      offset = size * Enum.random(0..round(0.5 / size))
      offset2 = size * Enum.random(0..round(1 / size))

      {:ok, loc1} = Location.new(lng, lat)
      # offset = size * 2
      # offset2 = size * 2

      loc2 = Location.wrapping_new(lng + offset, lat + offset2)

      {loc1, loc2}
    end
  end

  def location() do
    let {lng, lat} <- {lng(), lat()} do
      {:ok, loc} = Location.new(lng, lat)
      loc
    end
  end

  def lat(), do: float(-90.0, 90.0)
  def lng(), do: float(-180.0, 180.0)

  def edge_lat() do
    frequency([
      {30, float(-90.0, -89.0)},
      {15, float(-80.0, -10.0)},
      {20, float(-10.0, 10.0)},
      {15, float(10.0, 80.0)},
      {30, float(80.0, 90.0)}
    ])
  end

  def edge_lng() do
    frequency([
      {40, float(-180.0, -175.0)},
      {15, float(-175.0, -10.0)},
      {10, float(-10.0, 10.0)},
      {15, float(10.0, 175.0)},
      {40, float(175.0, 180.0)}
    ])
  end
end
