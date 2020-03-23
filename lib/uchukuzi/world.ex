defmodule Uchukuzi.World do
  alias Uchukuzi.Report
  alias Uchukuzi.Location
  alias Uchukuzi.World.TileServer
  alias Uchukuzi.World.TileSupervisor
  alias Uchukuzi.World.Tile

  # TODO: What happens when these updates are within the school
  def update(bus_server, %Report{} = previous_report, %Report{} = current_report) do
    current_tile = tile_server_for(current_report)
    previous_tile = tile_server_for(previous_report)

    if current_tile == previous_tile do
      moved(current_tile, bus_server, current_report)
    else
      tiles = crossed_tiles(previous_report, current_report)

      {time_exiting, average_cross_time, time_entering} =
        calculate_time(
          previous_report,
          current_report,
          tile_for(previous_report),
          tiles,
          tile_for(current_report)
        )

      exited(previous_tile, bus_server, previous_report.time + time_exiting)
      crossed(tiles, bus_server, average_cross_time)

      entered(
        current_tile,
        bus_server,
        current_report.time - time_entering,
        current_report.location
      )
    end
  end

  defp tile_for(%Report{} = report),
    do: tile_for(report.location)

  defp tile_for(%Location{} = location) do
    Tile.new(location)
  end

  defp tile_server_for(%Report{} = report),
    do: tile_server_for(report.location)

  defp tile_server_for(%Location{} = location) do
    TileSupervisor.tile_for(location)
  end

  defp moved(tile_server, bus_server, %Report{} = current_report) do
    TileServer.moved(tile_server, bus_server, current_report)
  end

  defp exited(tile_server, bus_server, time) do
    TileServer.exited(tile_server, bus_server, time)
  end

  defp entered(tile_server, bus_server, time, location) do
    TileServer.entered(tile_server, bus_server, time, location)
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
    |> Enum.filter(&Tile.intesects?(&1, path))
  end

  defp crossed(tiles, bus_server, average_time) do
    tiles
    |> Enum.map(&TileSupervisor.tile_for/1)
    |> Enum.map(&TileServer.crossed(&1, bus_server, average_time))
  end

  @spec calculate_time(Uchukuzi.Report.t(), Uchukuzi.Report.t(), any, any, any) ::
          {float, float, float}
  defp calculate_time(previous_report, current_report, previous_tile, tiles, current_tile) do
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

    distance_exiting = Tile.distance_inside(previous_tile, path, true)

    distance_entering = Tile.distance_inside(current_tile, path, false)

    tiles_crossed =
      tiles
      |> Enum.count()

    distance_crossing = total_distance - distance_exiting - distance_entering

    total_time = current_report.time - previous_report.time

    average_time =
      if tiles_crossed == 0 do
        0
      else
        total_time * distance_crossing / total_distance / tiles_crossed
      end

    {total_time * distance_exiting / total_distance, average_time,
     total_time * distance_entering / total_distance}
  end
end
