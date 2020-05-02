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
    PubSub.subscribe(self(), :prediction_update)

    {:ok, state}
  end

  def handle_info(event, state) do
    IO.inspect(event)

    {:noreply, state}
  end
end
