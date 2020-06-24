defmodule Uchukuzi.World do
  @moduledoc """
  The World module modules the real-world by maintaining a map of the world
  and keeping track of where each bus is in relation with world.any()

  The world is represented by a grid of `Uchukuzi.World.Tile`s that contain
  information about the time when each bus entered the grid and the amount of
  time it took to cross the tile.

  When a bus exits a tile, information about the cross-time is forwarded
  to the `Uchukuzi.World.ETA` module. The module stores this information and
  later performs learning on it. The models built by the `Uchukuzi.World.ETA`
  module are later used to predict the time taken to cross through a sequence
  of tiles when making a trip.
  """
  alias Uchukuzi.Common.Report
  alias Uchukuzi.Common.Location
  alias Uchukuzi.World.WorldManager
  alias Uchukuzi.World.TileServer
  alias Uchukuzi.World.TileSupervisor
  alias Uchukuzi.World.Tile

  def update(bus_server, previous_report, current_report) do
    current_tile = tile_for(current_report)

    # if this is the first report we have ever received,
    if previous_report == nil do
      # let the current tile know that the bus is now inside it.
      TileSupervisor.enter(bus_server, current_tile, current_report.time)

      # It has not yet crossed anything
      # so return an empty list
      []
    else
      current_report = current_report
      previous_report = previous_report

      # This is where the bus was the last time it reported
      previous_tile = tile_for(previous_report)

      # if the bus is still in the same tile
      if current_tile == previous_tile do
        # do nothing and report nothing
        []
      else
        # if the bus changed tiles then

        # check whether some other tiles were crossed when moving from
        # the previous tile to the current tile
        crossed_tiles = crossed_tiles(previous_report, current_report)

        # for the time between the previous report and the current report,
        # calculate when the bus left the previous tile,
        #           how much was spent crossing each of the intermediate tiles
        #           when the bus entered the current tile
        {exit_time, average_time_to_cross, entry_time} =
          calculate_time(
            previous_report,
            current_report,
            previous_tile,
            crossed_tiles,
            current_tile
          )

        # Let the previous tile know that the bus has left it
        TileSupervisor.leave(bus_server, previous_tile, exit_time)

        # Let each of the intermediate tiles know that they were crossed
        # and that the crossing took on average x seconds
        WorldManager.crossed_tiles(
          crossed_tiles,
          bus_server,
          average_time_to_cross,
          exit_time
        )

        # Let the current tile know that the bus has entered it at a time y
        TileSupervisor.enter(
          bus_server,
          current_tile,
          entry_time
        )

        # Return the information that the previous tile was exited and
        # that intermediate tiles were crossed
        [previous_tile | crossed_tiles]
      end
    end
  end

  defp tile_for(%{location: %Location{} = location}),
    do: tile_for(location)

  defp tile_for(%Location{} = location) do
    Tile.new(location)
  end

  # Calculate which tiles (other than the start tile and end tile)
  # are crossed if we were to draw a line, as the crow flies, from
  # the previous report to the current report
  #
  # This allows us to learn even when some tiles
  # are skipped
  def crossed_tiles(%Report{} = previous_report, %Report{} = current_report) do
    crossed_tiles(previous_report.location, current_report.location)
  end

  def crossed_tiles(previous_location, current_location) do
    start_tile = Tile.new(previous_location)
    end_tile = Tile.new(current_location)

    path = %Geo.LineString{
      coordinates: [
        Location.to_coord(previous_location),
        Location.to_coord(current_location)
      ]
    }

    # Get all possible tiles that could be crossed
    Tile.tiles_between(start_tile, end_tile)
    # Filter out non intersecting
    # `Tile.distance_inside` returns {:ok, distance} only if the tile is
    # crossed by the line
    |> Enum.map(&{&1, Tile.crossed_by?(&1, path)})
    |> Enum.flat_map(fn {tile, result} ->
      case result do
        {:ok, distance} -> [{tile, distance}]
        _ -> []
      end
    end)
    # Sort first to last
    |> Enum.sort_by(fn {_, distance} -> distance end)
    # Map to tile
    |> Enum.map(fn {tile, _} -> tile end)
  end

  defp calculate_time(previous_report, current_report, previous_tile, crossed_tiles, current_tile) do
    # Get the distance travelled assuming a straight line
    total_distance =
      Uchukuzi.Common.Location.distance_between(
        Report.to_coord(previous_report),
        Report.to_coord(current_report)
      )

    path = %Geo.LineString{
      coordinates: [
        Report.to_coord(previous_report),
        Report.to_coord(current_report)
      ]
    }

    case DateTime.diff(current_report.time, previous_report.time) do
      # Prevent divisions by 0 in the next clause
      0 ->
        {0, 0, 0}

      total_time ->
        average_speed = total_distance / total_time

        {:ok, distance_exiting} = Tile.distance_inside(previous_tile, path, true)

        {:ok, distance_entering} = Tile.distance_inside(current_tile, path, false)

        tiles_crossed =
          crossed_tiles
          |> Enum.count()

        distance_crossing = total_distance - distance_exiting - distance_entering

        average_time =
          if tiles_crossed == 0 do
            0
          else
            time_spent_crossing = total_time * (distance_crossing / total_distance)
            time_spent_crossing / tiles_crossed
          end

        time_exiting = distance_exiting / average_speed
        time_entering = distance_entering / average_speed

        {DateTime.add(previous_report.time, round(time_exiting), :second), average_time,
         DateTime.add(current_report.time, round(-time_entering), :second)}
    end
  end
end
