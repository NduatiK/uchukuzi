defmodule UchukuziInterfaceWeb.ChannelForwarder do
  @moduledoc """
  The `#{__MODULE__}` subscribes to messages  from the `Uchukuzi` module
   concerning updates in the predicted arrival time of a vehicle to
   tiles on its route.
  """
  use GenServer
  alias Uchukuzi.Common.Location

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(state) do
    PubSub.subscribe(self(), :eta_prediction_update)
    PubSub.subscribe(self(), :trip_update)

    {:ok, state}
  end

  def handle_info({:eta_prediction_update, _tracker_pid, nil, _eta_sequence} = _event, state) do
    {:noreply, state}
  end

  def handle_info({:eta_prediction_update, _tracker_pid, route_id, eta_sequence} = _event, state) do
    eta_sequence
    |> Enum.map(fn
      {%Location{} = loc, time} ->
        {Uchukuzi.World.ETA.coordinate_hash(loc), time}

      {loc, time} when is_binary(loc) ->
        {loc, time}
    end)
    |> Enum.map(fn {tile_hash, eta} ->
      UchukuziInterfaceWeb.CustomerSocket.PredictionsChannel.send_prediction(
        route_id,
        tile_hash,
        %{eta: eta + 0.0}
      )
    end)

    {:noreply, state}
  end

  def handle_info({:trip_update, _tracker_pid, bus_id, update} = _event, state) do
    UchukuziInterfaceWeb.TripChannel.send_trip_update(bus_id, update)
    {:noreply, state}
  end
end
