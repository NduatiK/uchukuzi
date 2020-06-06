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
    PubSub.subscribe(self(), :trip_started)

    PubSub.subscribe(self(), :trip_update)
    PubSub.subscribe(self(), :approaching_tile)
    PubSub.subscribe(self(), :eta_prediction_update)

    PubSub.subscribe(self(), :trip_ended)

    {:ok, state}
  end

  def handle_info({:trip_started, route_id, students_onboard} = _event, state) do
    UchukuziInterfaceWeb.CustomerSocket.BusChannel.send_bus_event(route_id, %{
      event: "left_school",
      students_onboard: students_onboard
    })

    {:noreply, state}
  end

  def handle_info({:approaching_tile, route_id, tile, travel_time, students_onboard}, state)
      when travel_time in ["morning", "evening"] do
    tile_hash =
      case tile do
        %Location{} = loc ->
          Uchukuzi.World.ETA.coordinate_hash(loc)

        loc ->
          loc
      end

    UchukuziInterfaceWeb.CustomerSocket.PredictionsChannel.send_event(
      route_id,
      tile_hash,
      %{
        event: "approaching_" <> travel_time,
        students_onboard: students_onboard
      }
    )

    {:noreply, state}
  end

  def handle_info({:eta_prediction_update, nil, _eta_sequence} = _event, state) do
    {:noreply, state}
  end

  def handle_info({:eta_prediction_update, route_id, eta_sequence} = _event, state) do
    eta_sequence
    |> Enum.map(fn
      {%Location{} = loc, time} ->
        {Uchukuzi.World.ETA.coordinate_hash(loc), time}

      {loc, time} when is_binary(loc) ->
        {loc, time}
    end)
    |> IO.inspect()
    |> Enum.map(fn {tile_hash, eta} ->
      UchukuziInterfaceWeb.CustomerSocket.PredictionsChannel.send_prediction(
        route_id,
        tile_hash,
        %{eta: eta + 0.0}
      )
    end)

    {:noreply, state}
  end

  def handle_info({:trip_update, bus_id, update} = _event, state) do
    UchukuziInterfaceWeb.TripChannel.send_trip_update(bus_id, update)
    {:noreply, state}
  end

  def handle_info({:trip_ended, route_id, students_onboard} = _event, state) do
    UchukuziInterfaceWeb.CustomerSocket.BusChannel.send_bus_event(route_id, %{
      event: "arrived_at_school",
      students_onboard: students_onboard
    })

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
