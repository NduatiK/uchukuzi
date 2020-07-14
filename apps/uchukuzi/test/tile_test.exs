defmodule UchukuziTest.TileTest do
  use ExUnit.Case
  use PropCheck
  import PropCheck

  alias Uchukuzi.World.Tile
  alias UchukuziTest.LocationGenerator
  alias Uchukuzi.Common.Location

  @moduledoc """
  This module tests the external API of the `Tile` module

  * def new(%Location{} = location)
  * def nearby(tile, radius \\ 1)
  * def nearby?(tile1, tile2, radius \\ 1)
  * def tiles_between(%Tile{} = start_tile, %Tile{} = end_tile)

  def distance_inside(tile, %Geo.LineString{} = path, is_entering_tile \\ false)
  def distance_from_start(tile, %Geo.LineString{} = path)
  """

  describe "test Tile.new/1" do
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
  end

  # end

  describe "test Tile.nearby/2 and Tile.nearby?/3" do
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

          assert nearby_tiles == expected_tiles
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
  end

  describe " test Tile.tiles_between/2" do
    property "there are no tiles between a tile and itself" do
      forall location <- LocationGenerator.location(), [:verbose] do
        tile = Tile.new(location)

        tiles_between = Tile.tiles_between(tile, tile)

        assert Enum.count(tiles_between) == 0
      end
    end

    property "it wraps the shortest way round the world and produces the correct number of tiles" do
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

    property "it only produces valid tiles" do
      forall {loc1, loc2} <- LocationGenerator.edge_locations(), [:verbose] do
        tile1 = Tile.new(loc1)

        tile2 = Tile.new(loc2)

        tiles_between = Tile.tiles_between(tile1, tile2)

        uniq_tiles =
          tiles_between
          |> Enum.uniq()
          |> Enum.count()

        # No repeats
        assert Enum.count(tiles_between) == uniq_tiles

        in_range =
          tiles_between
          |> Enum.all?(fn tile ->
            tile |> between_tiles?(tile1, tile2)
          end)

        assert in_range
      end
    end
  end

  describe " test Tile.distance_from_start/2" do
    # def distance_inside(tile, %Geo.LineString{} = path, is_entering_tile \\ false)
    # def distance_from_start(tile, %Geo.LineString{} = path)

    property "it returns does not cross for uncrossed locations" do
      forall {loc1, loc2} <- LocationGenerator.edge_locations(), [:verbose] do
        tile1 = Tile.new(loc1)
        tile2 = Tile.new(loc2)
        tiles_between = Tile.tiles_between(tile1, tile2)
        path1to2 = path(loc1, loc2)

        forall location <-
                 oneof([
                   LocationGenerator.location(),
                   oneof((tiles_between |> Enum.map(& &1.coordinate)) ++ [loc1])
                 ]) do
          tile = Tile.new(location)

          if tile |> between_tiles?(tile1, tile2) do
            assert true
          else
            assert Tile.distance_from_start(tile, path1to2) == :does_not_cross
          end
        end
      end
    end
  end

  def path(%Tile{} = tile1, %Tile{} = tile2) do
    path(tile1.coordinate, tile2.coordinate)
  end

  def path(loc1, loc2) do
    %Geo.LineString{
      coordinates: [
        Location.to_coord(loc1),
        Location.to_coord(loc2)
      ]
    }
  end

  def floor_to_grid(float) do
    (float / default_tile_size())
    |> round()
    |> (&(&1 * default_tile_size())).()
    |> round4dp()
  end

  def between_tiles?(%Tile{coordinate: tile}, %Tile{coordinate: tile1}, %Tile{
        coordinate: tile2
      }) do
    between_lats =
      (tile1.lat <= tile.lat and tile.lat <= tile2.lat) or
        (tile2.lat <= tile.lat and tile.lat <= tile1.lat)

    {lng1, lng2} =
      if tile1.lng > tile2.lng do
        {tile1.lng, tile2.lng}
      else
        {tile2.lng, tile1.lng}
      end

    lng = tile.lng

    between_lngs =
      if lng1 - lng2 > 180 do
        lng1 - 360 <= lng and lng <= lng2 + 360
      else
        lng2 <= lng and lng <= lng1
      end

    between_lats and between_lngs
  end

  def default_tile_size() do
    Tile.default_tile_size()
  end

  def round4dp(float) do
    Float.round(float, 4)
  end
end
