defmodule Uchukuzi.World.WorldManager do
  use GenServer

  alias Uchukuzi.School.Route

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
    {:ok, state}
  end

  def bus_crossed_tile(bus, tile, time) do
    GenServer.cast(GenServer.whereis(@name), {:crossed, bus, tile, time})
  end

  def arrived_at_stop(server, route_stop, tile, time_in_tile) do
  end

  @spec predict_time_to_tile(any, any, any) :: nil
  def predict_time_to_tile(server, current_tile, tile) do
  end
end
