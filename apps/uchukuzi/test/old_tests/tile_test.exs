# defmodule TripTrackerTest do
#   use ExUnit.Case
#   doctest Uchukuzi

#   alias Uchukuzi.World.Tile
#   alias Uchukuzi.Common.Location

#   test "trip correctly gets all between tile" do
#     size = 0.5
#     {:ok, start_location} = Location.new(0, 0)
#     start_tile = Tile.new(start_location, size)

#     [
#       {1, 1, 9},
#       {0.9, 0.9, 4},
#       {3, 0, 7},
#       {1, 0, 3}
#     ]
#     |> Enum.map(fn {end_x, end_y, expected_tiles_count} = data ->
#       {:ok, end_location} = Location.new(end_x, end_y)
#       end_tile = Tile.new(end_location, size)

#       found_tiles = Tile.tiles_between(start_tile, end_tile, size)
#       assert Enum.count(found_tiles) == expected_tiles_count
#     end)
#   end
# end
