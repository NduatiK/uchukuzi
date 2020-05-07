defmodule UchukuziInterfaceWeb.PredictionForwarder do
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

    {:ok, state}
  end

  # GenServer.whereis UchukuziInterfaceWeb.PredictionForwarder
  # send(pid, {:eta_prediction_update, 0, 2, [{"CDUAGGDOARXDTACFIRPVCZBHKC5S5BKY", 8}]})
  # CDUAGGDOARXDTACFIRPVCZBHKC5S5BKY
  def handle_info({:eta_prediction_update, _tracker_pid, route_id, eta_sequence} = _event, state) do
    UchukuziInterfaceWeb.RouteChannel.send_to_channel(
      route_id,
      "prediction_update",
      %{
        route_id: route_id,
        eta_sequence:
          eta_sequence
          |> Enum.map(fn
            {%Location{} = loc, time} ->
              %{
                id: Uchukuzi.World.ETA.coordinate_hash(loc),
                time: time
              }

            {loc, time} when is_binary(loc) ->
              %{
                id: loc,
                time: time
              }
          end)
      }
    )

    {:noreply, state}
  end
end
