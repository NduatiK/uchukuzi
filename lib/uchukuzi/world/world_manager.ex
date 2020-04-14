defmodule Uchukuzi.World.WorldManager do
  use GenServer

  alias Uchukuzi.School.Route
  alias Uchukuzi.DiskDB, as: DB

  @moduledoc """
  Keeps track of the world and provides the following fuctionality:

  * Tile History
  Receives information on the time taken to cross a `Tile` for
  later use in making ETA predictions


  * Route Learning
  Learns the sequence of tiles followed by a bus on a given `Route`


  * ETA Prediction
  Given a stop along a route, predicts the time it will take to arrive
  """
  @name __MODULE__

  def start_link(_options),
    do: GenServer.start_link(__MODULE__, [], name: @name)

  def init(_arg) do
    state = []
    DB.createTable(__MODULE__)
    # send(self(), :train)
    {:ok, state}
  end

  def handle_call(
        {:crossed_tiles, tiles, _bus_server, average_cross_time, time_of_day},
        _from,
        state
      ) do
    time_value = time_of_day.hour + time_of_day.minute / 60

    for tile <- tiles do
      with {:ok, dataset} <- DB.get(tile.coordinate, @name) do
        [[time_value, average_cross_time] | dataset]
        |> Enum.take(1000)
        |> DB.insert(@name, tile.coordinate)
      else
        {:error, "does not exist"} ->
          [[time_value, average_cross_time]]
          |> DB.insert(@name, tile.coordinate)
      end
    end

    {:reply, state, state}
  end

  def handle_call({:crossed_tile, tile, _bus_server, cross_time, time_of_day}, _from, state) do
    time_value = time_of_day.hour + time_of_day.minute / 60

    with {:ok, dataset} <- DB.get(tile.coordinate, @name) do
      [[time_value, cross_time] | dataset]
      |> Enum.take(1000)
      |> DB.insert(@name, tile.coordinate)
    else
      {:error, "does not exist"} ->
        [[time_value, cross_time]]
        |> DB.insert(@name, tile.coordinate)
    end

    {:reply, state, state}
  end

  # ******** Client API ********
  def crossed_tile(tile, bus_server, cross_time, time_of_day) do
    GenServer.call(
      GenServer.whereis(@name),
      {:crossed_tile, tile, bus_server, cross_time, time_of_day}
    )
  end

  def crossed_tiles(tiles, bus_server, average_cross_time, time_of_day) do
    GenServer.call(
      GenServer.whereis(@name),
      {:crossed_tiles, tiles, bus_server, average_cross_time, time_of_day}
    )
  end
end
