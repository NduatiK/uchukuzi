defmodule UchukuziTest.TileTest do
  use ExUnit.Case
  use PropCheck
  import PropCheck

  alias Uchukuzi.World.Tile
  alias UchukuziTest.LocationGenerator

  @moduledoc """
  This module tests the external API of the `Tile` module

  * def new(%Location{} = location)
  * def nearby(tile, radius \\ 1)
  * def nearby?(tile1, tile2, radius \\ 1)
  * def tiles_between(%Tile{} = start_tile, %Tile{} = end_tile)

  def distance_inside(tile, %Geo.LineString{} = path, is_entering_tile \\ false)


  def cross_distance(tile, %Geo.LineString{} = path)
  """

  property "a created tile contains the location used to create it" do
    forall location <- LocationGenerator.location() do
      tile = Tile.new(location)

      location.lng - tile.coordinate.lng < default_tile_size() and
        location.lng - tile.coordinate.lng >= 0 and
        location.lat - tile.coordinate.lat < default_tile_size() and
        location.lat - tile.coordinate.lat >= 0
    end
  end

  property "tiles are always positioned along the grid" do
    forall location <- LocationGenerator.location() do
      tile = Tile.new(location)

      floorToGrid(tile.coordinate.lng) == tile.coordinate.lng and
        floorToGrid(tile.coordinate.lat) == tile.coordinate.lat
    end
  end

  @doc """
  🔳🔳🔳
  🔳🔲🔳
  🔳🔳🔳
  """
  property "a tile returns the correct number of nearby tiles" do
    forall location <- LocationGenerator.location() do
      forall radius <- such_that(n <- integer(), when: 0 <= n and n < 10) do
        tile = Tile.new(location)

        square_of_tiles_size = radius * 2 + 1

        Tile.nearby(tile, radius) |> Enum.count() == :math.pow(square_of_tiles_size, 2) - 1
      end
    end
  end

  property "generated nearby tiles are truly `nearby?`" do
    forall location <- LocationGenerator.location() do
      forall radius <- such_that(n <- integer(), when: 0 <= n and n < 10) do
        tile = Tile.new(location)

        Tile.nearby(tile, radius)
        |> Enum.all?(fn tile2 -> Tile.nearby?(tile, tile2, radius) end)
      end
    end
  end

  property "nearby? rejects all tiles outside radius" do
    forall location <- LocationGenerator.location() do
      forall radius <- such_that(n <- integer(), when: 0 <= n and n < 10) do
        tile = Tile.new(location)

        tiles_in_radius = Tile.nearby(tile, radius)

        tiles_outside_radius =
          tile
          |> Tile.nearby(5 + radius)
          |> Enum.reject(fn x -> x in tiles_in_radius end)

        tiles_outside_radius
        |> Enum.all?(fn tile2 ->
          not Tile.nearby?(tile, tile2, radius)
        end)
      end
    end
  end

  property "tiles_between wraps the shortest way round the world" do
    forall {loc1, loc2} <- LocationGenerator.edge_locations(), [:verbose] do
      tile1 = Tile.new(loc1)
      tile2 = Tile.new(loc2)

      naive_lng_distance = abs(tile1.coordinate.lng - tile2.coordinate.lng)

      # We need to handle the wrap around
      shortest_lng_distance =
        if naive_lng_distance > 180 do
          360 - naive_lng_distance
        else
          naive_lng_distance
        end

      shortest_lng_tiles = round(shortest_lng_distance / default_tile_size()) + 1

      shortest_lat_distance = abs(tile1.coordinate.lat - tile2.coordinate.lat)
      shortest_lat_tiles = round(shortest_lat_distance / default_tile_size()) + 1

      expectation = shortest_lat_tiles * shortest_lng_tiles - 2

      # IO.inspect({shortest_lng_tiles, shortest_lat_tiles})
      # IO.inspect({Enum.count(tiles_between), expectation})

      tiles_between = Tile.tiles_between(tile1, tile2)

      assert Enum.count(tiles_between) == expectation
    end
  end

  def floorToGrid(float) do
    (float / default_tile_size())
    |> round()
    |> (&(&1 * default_tile_size())).()
    |> round4dp()
  end

  def boolean(_) do
    true
  end

  def default_tile_size() do
    Tile.default_tile_size()
  end

  def round4dp(float) do
    Float.round(float, 4)
  end
end
