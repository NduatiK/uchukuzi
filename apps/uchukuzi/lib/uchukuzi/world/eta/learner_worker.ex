defmodule Uchukuzi.World.ETA.LearnerWorker do
  use GenServer
  use Export.Python

  alias Uchukuzi.World.ETA
  alias Uchukuzi.World.ETA.ETASupervisor

  @python_dir "../uchukuzi/lib/python"
  @python_module "ml"
  @python_method "learn"


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
  def handle_call({coordinate, dataset}, _from, state) do
    result =
      state.py
      |> Python.call(@python_module, @python_method, [ETA.coordinate_hash(coordinate), dataset])

    {:reply, [result], state}
  end

  def learn(coordinate, {:ok, dataset}), do: learn(coordinate, dataset)

  def learn(coordinate, dataset) do
    :poolboy.transaction(
      ETASupervisor.learner_pool(),
      fn pid -> GenServer.call(pid, {coordinate, dataset}) end
    )
  end
end
