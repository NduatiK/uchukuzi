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
  def distance_from_start(tile, %Geo.LineString{} = path)
  """

  property "a created tile contains the location used to create it" do
    size = default_tile_size()

    forall location <- LocationGenerator.location() do
      tile = Tile.new(location).coordinate

      tile.lng <= location.lng and location.lng < tile.lng + size and
        tile.lat <= location.lat and location.lat < tile.lat + size
    end
  end

  property "tiles are always positioned along the grid" do
    forall location <- LocationGenerator.location() do
      tile = Tile.new(location)

      floor_to_grid(tile.coordinate.lng) == tile.coordinate.lng and
        floor_to_grid(tile.coordinate.lat) == tile.coordinate.lat
    end
  end

  @doc """
  🔳🔳🔳
  🔳🔲🔳
  🔳🔳🔳
  """
  property "a tile returns the correct number of nearby tiles" do
    forall location <- LocationGenerator.location(), [:verbose] do
      forall radius <- such_that(n <- integer(), when: 0 <= n and n < 10) do
        tile = Tile.new(location)

        square_of_tiles_size = radius * 2 + 1

        nearby_tiles =
          tile
          |> Tile.nearby(radius)
          |> Enum.uniq()
          |> Enum.count()

        assert expected_tiles = :math.pow(square_of_tiles_size, 2) - 1

        nearby_tiles == expected_tiles
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
      lng_distance =
        if naive_lng_distance > 180 do
          360 - naive_lng_distance
        else
          naive_lng_distance
        end

      h_tile_count = round(lng_distance / default_tile_size()) + 1

      lat_distance = abs(tile1.coordinate.lat - tile2.coordinate.lat)
      v_tile_count = round(lat_distance / default_tile_size()) + 1

      expectation = v_tile_count * h_tile_count - 2

      tiles_between = Tile.tiles_between(tile1, tile2)

      assert Enum.count(tiles_between) == expectation
    end
  end

  def floor_to_grid(float) do
    (float / default_tile_size())
    |> round()
    |> (&(&1 * default_tile_size())).()
    |> round4dp()
  end

  def default_tile_size() do
    Tile.default_tile_size()
  end

  def round4dp(float) do
    Float.round(float, 4)
  end
end
