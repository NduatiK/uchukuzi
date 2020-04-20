defmodule Uchukuzi.World do
  alias Uchukuzi.Common.Report
  alias Uchukuzi.Common.Location
  alias Uchukuzi.World.WorldManager
  alias Uchukuzi.World.TileServer
  alias Uchukuzi.World.TileSupervisor
  alias Uchukuzi.World.Tile

  # TODO: What happens when these updates are within the school
  def update(bus_server, previous_report, current_report) do
    current_tile = tile_for(current_report)

    if previous_report == nil do
      TileSupervisor.enter(bus_server, current_tile, current_report.time)
      [current_tile]
    else
      current_report = Report.to_report(current_report)
      previous_report = Report.to_report(previous_report)
      previous_tile = tile_for(previous_report)

      if current_tile == previous_tile do
        []
      else
        crossed_tiles = crossed_tiles(previous_report, current_report)

        {exit_time, average_cross_time, entry_time} =
          calculate_time(
            previous_report,
            current_report,
            previous_tile,
            crossed_tiles,
            current_tile
          )

        # IO.inspect("leave")

        TileSupervisor.leave(bus_server, previous_tile, exit_time)

        time_of_day =
          DateTime.diff(current_report.time, previous_report.time, :millisecond)
          |> (fn diff -> round(diff / 2) end).()
          |> (fn diff -> DateTime.add(previous_report.time, diff, :millisecond) end).()

        WorldManager.crossed_tiles(
          crossed_tiles,
          bus_server,
          average_cross_time,
          time_of_day
        )

        TileSupervisor.enter(
          bus_server,
          current_tile,
          entry_time
        )

        [previous_tile] ++ crossed_tiles ++ [current_tile]
      end
    end
  end

  defp tile_for(%{location: %Location{} = location}),
    do: tile_for(location)

  defp tile_for(%Location{} = location) do
    Tile.new(location)
  end

  defp crossed_tiles(previous_report, current_report) do
    start_tile = Tile.new(previous_report.location)
    end_tile = Tile.new(current_report.location)

    path = %Geo.LineString{
      coordinates: [
        Report.to_coord(previous_report),
        Report.to_coord(current_report)
      ]
    }

    Tile.tiles_between(start_tile, end_tile)
    |> Enum.map(&{&1, Tile.distance_inside(&1, path)})
    # Filter out non intersecting
    |> Enum.flat_map(fn {tile, result} ->
      case result do
        {:ok, distance} -> [{tile, distance}]
        _ -> []
      end
    end)
    # Sort nearest to farthest
    |> Enum.sort_by(fn {_, distance} -> distance end)
    # Map to tile
    |> Enum.map(fn {tile, _} -> tile end)
  end

  defp calculate_time(previous_report, current_report, previous_tile, crossed_tiles, current_tile) do
    path = %Geo.LineString{
      coordinates: [
        Report.to_coord(previous_report),
        Report.to_coord(current_report)
      ]
    }

    total_distance =
      Distance.distance(
        Report.to_coord(previous_report),
        Report.to_coord(current_report)
      )

    case DateTime.diff(current_report.time, previous_report.time) do
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
            total_time * (distance_crossing / total_distance) / tiles_crossed
          end

        time_exiting = distance_exiting / average_speed
        time_entering = distance_entering / average_speed

        {DateTime.add(previous_report.time, round(time_exiting * 1000), :millisecond),
         average_time,
         DateTime.add(current_report.time, round(-time_entering * 1000), :millisecond)}
    end
  end
end
