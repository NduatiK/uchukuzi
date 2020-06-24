defmodule Uchukuzi.World.Tile do
  @default_tile_size_metres 111_111 / 100 / 2 / 2
  @default_tile_size 0.0025

  @moduledoc """
  A square representing a region in the world

  The `coordinate` is the location of the bottom left most
  part of the grid tile.

  The `opposite_coordinate` is the location of the top-right
  most part of the grid tile.

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

  Our default tile is a square `#{@default_tile_size_metres}` m wide.
  """

  alias __MODULE__
  alias Uchukuzi.Common.Location

  @enforce_keys [:coordinate]
  defstruct [:coordinate]

  def new(%Location{} = location) do
    %Tile{coordinate: to_origin(location)}
  end

  @doc """
  Determines the distance covered by a vehicle as it was moving into or out of a Tile
  """
  def distance_inside(tile, %Geo.LineString{} = path, is_leaving \\ false) do
    tile
    |> to_polygon()
    |> to_paths
    |> distances_for_intersecting_paths(path, is_leaving)
    |> Enum.sort(&>=/2)
    |> (fn
          x ->
            case x do
              [head | _] ->
                {:ok, head}

              [] ->
                :error
            end
        end).()
  end

  @doc """
  Given two tiles, calculate all the tiles through which a straight line connecting
  the two *could* pass through.
  """
  def tiles_between(%Tile{} = start_tile, %Tile{} = end_tile) do
    start_lng = start_tile.coordinate.lng
    start_lat = start_tile.coordinate.lat

    lat_diff = round((end_tile.coordinate.lat - start_tile.coordinate.lat) / @default_tile_size)
    lng_diff = round((end_tile.coordinate.lng - start_tile.coordinate.lng) / @default_tile_size)

    for lat <- 0..lat_diff, lng <- 0..lng_diff do
      Location.new(
        Float.round(start_lng + lng * @default_tile_size, 4),
        Float.round(start_lat + lat * @default_tile_size, 4)
      )
    end
    |> Enum.reject(&(&1 == :error))
    |> Enum.map(fn {:ok, location} -> location end)
    |> Enum.reject(&(&1 == start_tile || &1 == end_tile || &1 == nil))
  end

  def nearby(tile, radius \\ 1) do
    for lat_offset <- -radius..radius,
        lng_offset <- -radius..radius,
        not (lat_offset == 0 and lng_offset == 0) do
      {:ok, location} =
        Location.new(
          tile.coordinate.lng + lng_offset * @default_tile_size,
          tile.coordinate.lat + lat_offset * @default_tile_size
        )

      Tile.new(location)
    end
  end

  def nearby?(tile1, tile2, radius \\ 1)

  def nearby?(%Tile{} = tile1, %Tile{} = tile2, radius) do
    nearby?(tile1.coordinate, tile2.coordinate, radius)
  end

  def nearby?(%Location{} = tile1, %Location{} = tile2, radius) do
    round(abs(tile1.lat - tile2.lat) / (radius * @default_tile_size)) <= 1 &&
      round(abs(tile1.lng - tile2.lng) / (radius * @default_tile_size)) <= 1
  end

  # Returns the origin of the grid tile that the point should be in
  defp to_origin(%Location{} = point) do
    size = @default_tile_size

    # Use floor so as to always move down and left,
    # even on negative coordinates
    {:ok, location} =
      Location.new(
        :math.floor(point.lng / size) * size,
        :math.floor(point.lat / size) * size
      )

    location |> rounded()
  end

  defp rounded(%Location{lat: lat, lng: lng}) do
    %Location{lat: Float.round(lat, 4), lng: Float.round(lng, 4)}
  end

  defp get_opposite_coordinate(%Tile{
        coordinate: %Uchukuzi.Common.Location{lat: origin_lat, lng: origin_lng}
      })
      when origin_lat + @default_tile_size < 90 and origin_lng + @default_tile_size < 180 do
    %Location{
      lng: origin_lng + @default_tile_size,
      lat: origin_lat + @default_tile_size
    }
    |> rounded()
  end

  # Converts a tile into a polygon
  defp to_polygon(%Tile{coordinate: coordinate} = tile) do
    opposite_coordinate =
      tile
      |> get_opposite_coordinate()

    %Geo.Polygon{
      coordinates: [
        [
          {coordinate.lng, coordinate.lat},
          {opposite_coordinate.lng, coordinate.lat},
          {opposite_coordinate.lng, opposite_coordinate.lat},
          {coordinate.lng, opposite_coordinate.lat},
          {coordinate.lng, coordinate.lat}
        ]
      ]
    }
  end

  # Converts a polygon into its set of constituent lines
  defp to_paths(%Geo.Polygon{coordinates: [coordinates]}) do
    coordinates
    # Join each point to the next point
    |> Enum.zip(coordinates |> Enum.drop(1))
    |> Enum.map(fn {point1, point2} ->
      %Geo.LineString{coordinates: [point1, point2]}
    end)
  end

  # Given a list of paths and a path A,
  # this finds the paths that intersect with A and returns
  # the distance covered before or after the intersection happened
  defp distances_for_intersecting_paths(
         paths,
         %Geo.LineString{coordinates: [start, finish]},
         distance_before
       ) do
    paths
    |> Enum.flat_map(fn %Geo.LineString{coordinates: [q1, q2]} ->
      case SegSeg.intersection(start, finish, q1, q2) do
        {true, _, {x, y}} ->
          if distance_before do
            [Distance.distance(start, {x, y})]
          else
            [Distance.distance(finish, {x, y})]
          end

        _ ->
          []
      end
    end)
    # |> IO.inspect
    |> (fn list ->
          case list do
            [x, x] ->
              # Crossed through the same point on two lines
              # ie only touched one vertex
              []

            _ ->
              list
          end
        end).()
  end
end
