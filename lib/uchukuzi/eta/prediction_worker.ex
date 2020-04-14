defmodule Uchukuzi.ETA.LearnerWorker do
  use GenServer
  use Export.Python

  alias Uchukuzi.ETA.ETASupervisor

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

    :ok
  end

  @impl true
  def handle_call({coordinate, time_value}, _from, state) do
    result =
      state.py
      |> Python.call(@python_module, @python_method, ["#{coordinate.lat}_#{coordinate.lng}", time_value])

    {:reply, [result], state}
  end

  def predict(coordinate, {:ok, time_value}), do: predict(coordinate, time_value)

  def predict(coordinate, time_value) do
    :poolboy.transaction(
      ETASupervisor.prediction_pool(),
      fn pid -> GenServer.call(pid, {coordinate, time_value}) end
    )
  end
end
