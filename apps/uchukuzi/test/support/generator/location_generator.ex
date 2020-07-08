defmodule UchukuziTest.LocationGenerator do
  use PropCheck
  import PropCheck
  alias Uchukuzi.Common.Location

  @doc """
  A locations generator with a higher likelihood
  of edge cases near the 180/-180° and 90/-90° line
  """
  def edge_locations() do
    let {lng, lat} <- {edge_lng(), lat()} do
      size = 0.0025
      offset = size * Enum.random(0..50)
      offset2 = size * Enum.random(0..100)

      {:ok, loc1} = Location.new(lng, lat)
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

  # Ignore the north and south pole
  def lat(), do: float(-88.0, 88.0)
  def lng(), do: float(-180.0, 180.0)

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
