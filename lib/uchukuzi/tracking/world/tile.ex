defmodule Uchukuzi.Tracking.World.Tile do
  @default_tile_size 1000 / 111_111
  @moduledoc """
  A tile is a process that keeps track of geographical regions
  in the real world as they relate to the location of vehicles


  #### Grid size
  Approximately,
  1 degree of latitude == 111,111 metres
  1 degree of longitude == 111,111 * cos(latitude) metres.
  As one approach the poles, the distance related to longitude
  degrees reduces to zero. But we don't care about the poles and
  the heuristic of 111,111 metres is accurate enough since we
  only care that the grid is large enough to provide information
  about how long it usually takes for a bus to cross it at a
  given time.


  We will use the approximation that,
  1 metre = 1 / 111,111° for both longitude and latitude

  Our default tile is a square `#{@default_tile_size}` km wide.
  """

  alias __MODULE__
  alias Uchukuzi.Location

  @doc """
  The `coordinate` is the location of the bottom left most
  part of the grid tile.

  The `opposite_coordinate` is the location of the top-right
  most part of the grid tile.
  """
  @enforce_keys [:coordinate, :opposite_coordinate]
  defstruct [:coordinate, :opposite_coordinate]

  def new(%Location{} = location) do
    location =
      location
      |> origin_of_tile()

    opposite_coordinate =
      location
      |> offset(@default_tile_size)

    %Tile{coordinate: location, opposite_coordinate: opposite_coordinate}
  end

  def offset(%Location{} = origin, offset) do
    lat =
      if origin.lat + offset > 90 do
        90
      else
        origin.lat + offset
      end

    lon =
      if origin.lon + offset > 180 do
        180
      else
        origin.lon + offset
      end

    %Location{
      lat: lat,
      lon: lon
    }
  end

  @doc """
  Returns the origin of the grid tile that the point should be in
  """
  def origin_of_tile(%Location{} = point) do
    # Use floor so as to always move down and left,
    # even on negative coordinates
    %Location{
      lat: :math.floor(point.lat / @default_tile_size) * @default_tile_size,
      lon: :math.floor(point.lon / @default_tile_size) * @default_tile_size
    }
  end
end
