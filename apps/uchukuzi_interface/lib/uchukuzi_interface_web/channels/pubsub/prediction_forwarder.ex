defmodule UchukuziInterfaceWeb.PredictionForwarder do
  @moduledoc """
  The `#{__MODULE__}` subscribes to messages  from the `Uchukuzi` module
   concerning updates in the predicted arrival time of a vehicle to
   tiles on its route.
  """
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(state) do
    PubSub.subscribe(self(), :eta_prediction_update)

    {:ok, state}
  end

  def handle_info({:eta_prediction_update, _tracker_pid, route_id, eta_sequence} = _event, state) do
    UchukuziInterfaceWeb.RouteChannel.send_to_channel(
      route_id,
      "prediction_update",
      %{
        route_id: route_id,
        eta_sequence:
          eta_sequence
          |> Enum.map(fn {loc, time} ->
            %{
              id: Uchukuzi.World.ETA.coordinate_hash(loc),
              time: time
            }
          end)
      }
    )

    {:noreply, state}
  end
end
