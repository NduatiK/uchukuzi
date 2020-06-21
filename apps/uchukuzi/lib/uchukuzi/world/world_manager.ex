defmodule Uchukuzi.World.WorldManager do
  use GenServer

  # alias Uchukuzi.School.Route

  @moduledoc """
  Keeps track of the world and provides the following fuctionality:

  * Tile History
  Receives information on the time taken to cross a `Tile` for
  later use in making ETA predictions
  """
  @name __MODULE__

  def start_link(_options),
    do: GenServer.start_link(__MODULE__, [], name: @name)

  def init(_arg) do
    state = []
    # send(self(), :train)
    {:ok, state}
  end

  def handle_call(
        {:crossed_tiles, tiles, _bus_server, average_cross_time, time_of_day},
        _from,
        state
      ) do

      tiles |> Enum.reduce(time_of_day, fn tile, time_of_day ->
              Uchukuzi.World.ETA.insert(tile, time_of_day, average_cross_time)
              DateTime.add(time_of_day, round(average_cross_time * 1000), :millisecond)
      end)

    {:reply, state, state}
  end

  def handle_call({:crossed_tile, tile, _bus_server, cross_time, time_of_day}, _from, state) do

    Uchukuzi.World.ETA.insert(tile, time_of_day, cross_time)

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
