defmodule Uchukuzi.World.Tile do
  # ~ 555m
  # @default_tile_size_metres 111_111 / 100 / 2
  # @default_tile_size @default_tile_size_metres / 111_111
  @default_tile_size_metres 111_111 / 100 / 2
  @default_tile_size 0.005

  @moduledoc """
  A square on the world's geographical

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

  @enforce_keys [:coordinate, :opposite_coordinate]
  defstruct [:coordinate, :opposite_coordinate, :polygon]

  defp get_size(size) do
    cond do
      size != nil ->
        size

      true ->
        with {:ok, size} <- Application.fetch_env(:uchukuzi, :default_tile_size) do
          size
        else
          _ ->
            @default_tile_size
        end
    end
  end

  def new(%Location{} = location, size \\ nil) do
    size = get_size(size)

    coordinate =
      location
      |> origin_of_tile(size)

    opposite_coordinate =
      coordinate
      |> offset(size)

    polygon = %Geo.Polygon{
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

    %Tile{coordinate: coordinate, opposite_coordinate: opposite_coordinate, polygon: polygon}
  end

  defp offset(%Location{} = origin, offset) do
    lat =
      if origin.lat + offset > 90 do
        90
      else
        origin.lat + offset
      end

    lng =
      if origin.lng + offset > 180 do
        180
      else
        origin.lng + offset
      end

    {:ok, location} = Location.new(lng, lat)
    location |> rounded()
  end

  @doc """
  Returns the origin of the grid tile that the point should be in
  """
  def origin_of_tile(%Location{} = point, size \\ nil) do
    size = get_size(size)

    # Use floor so as to always move down and left,
    # even on negative coordinates
    {:ok, location} =
      Location.new(
        :math.floor(point.lng / size) * size,
        :math.floor(point.lat / size) * size
      )

    location |> rounded()
  end

  def rounded(%Location{lat: lat, lng: lng}) do
    %Location{lat: Float.round(lat, 3), lng: Float.round(lng, 3)}
  end

  @doc """
  Determines the distance covered by a vehicle as it was moving into or out of a Tile
  """
  def distance_inside(tile, %Geo.LineString{} = path, is_leaving \\ false) do
    tile.polygon
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
  Converts a polygon into its set of constituent lines
  """
  defp to_paths(%Geo.Polygon{coordinates: coordinates}) do
    coordinates
    |> hd
    |> Enum.reduce({[], nil}, fn x, acc ->
      case acc do
        {paths, nil} -> {paths, x}
        {paths, prev} -> {[%Geo.LineString{coordinates: [prev, x]} | paths], x}
      end
    end)
    |> (fn {paths, _} -> paths end).()
  end

  @doc """
  Given a list of paths and a path A,
  this finds the paths that intersect with A and returns
  the distance covered before or after the intersection happened
  """
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
  end

  @doc """
  Given two tiles, calculate all the tiles through which a straight line connecting
  the two *could* pass through.
  """
  def tiles_between(%Tile{} = start_tile, %Tile{} = end_tile, size \\ nil) do
    size = get_size(size)

    {left_tile, right_tile} =
      if start_tile.coordinate.lat <= end_tile.coordinate.lat do
        {start_tile, end_tile}
      else
        {end_tile, start_tile}
      end

    {top_tile, bottom_tile} =
      if start_tile.coordinate.lng >= end_tile.coordinate.lng do
        {start_tile, end_tile}
      else
        {end_tile, start_tile}
      end

    horizontal = round((right_tile.coordinate.lat - left_tile.coordinate.lat) / size)

    vertical = round((top_tile.coordinate.lng - bottom_tile.coordinate.lng) / size)

    grouped_tiles =
      for lat <- 0..horizontal do
        for lng <- 0..vertical do
          {:ok, location} =
            Location.new(
              bottom_tile.coordinate.lng + lng * size,
              left_tile.coordinate.lat + lat * size
            )

          Tile.new(location, size)
        end
      end

    grouped_tiles
    |> Enum.flat_map(& &1)
    |> Enum.reject(&(&1 == start_tile || &1 == end_tile))
  end

  @doc """
  Generates a unique tuple for a tile
  """
  def name(%Tile{} = tile), do: tile.coordinate

  def nearby(tile, radius \\ 1) do
    for lat <- -radius..radius do
      for lng <- -radius..radius do
        if lat == 0 and lng == 0 do
          nil
        else
          {:ok, location} =
            Location.new(
              tile.coordinate.lng + lng * @default_tile_size,
              tile.coordinate.lat + lat * @default_tile_size
            )

          Tile.new(location, @default_tile_size)
        end
      end
    end
    |> Enum.flat_map(& &1)
    |> Enum.filter(fn x -> x != nil end)
  end

  def nearby?(tile1, tile2, radius \\ 1)

  def nearby?(%Tile{} = tile1, %Tile{} = tile2, radius) do
    nearby?(tile1.coordinate, tile2.coordinate, radius)
  end

  def nearby?(%Location{} = tile1, %Location{} = tile2, radius) do
    round(abs(tile1.lat - tile2.lat) / (radius * @default_tile_size)) <= 1 &&
      round(abs(tile1.lng - tile2.lng) / (radius * @default_tile_size)) <= 1
  end
end
