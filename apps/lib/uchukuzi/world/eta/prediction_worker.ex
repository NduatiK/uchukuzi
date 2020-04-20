defmodule Uchukuzi.World.ETA.PredictionWorker do
  use GenServer
  use Export.Python

  alias Uchukuzi.World.ETA
  alias Uchukuzi.World.ETA.ETASupervisor

  @python_dir "../uchukuzi/lib/python"
  @python_module "ml"
  @python_method "predict"

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, [])
  end

  @impl true
  def init(_) do
    {:ok, py} = Python.start_link(python_path: Path.expand(@python_dir))

    state = %{
      py: py
    }

    {:ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    state.py
    |> Python.stop()
    IO.inspect("Crash!!!")
    :ok
  end

  @impl true
  def handle_call({coordinate, hour_value}, _from, state) do
    result =
      state.py
      |> Python.call(@python_module, @python_method, [ETA.coordinate_hash(coordinate), hour_value])

    {:reply, [result], state}
  end


  def predict(coordinate, hour_value) do
    :poolboy.transaction(
      ETASupervisor.prediction_pool(),
      fn pid -> GenServer.call(pid, {coordinate, hour_value}) end
    )
  end
end
