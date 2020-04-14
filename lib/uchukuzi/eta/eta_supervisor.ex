defmodule Uchukuzi.ETA.ETASupervisor do
  use Supervisor

  @name __MODULE__
  alias Uchukuzi.ETA.PredictionWorker
  alias Uchukuzi.ETA.LearnerWorker

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def prediction_pool() do
    pool_name(PredictionWorker)
  end

  def learner_pool() do
    pool_name(LearnerWorker)
  end

  defp pool_name(module),
    do: String.to_atom(Atom.to_string(module) <> "Pool")

  defp poolboy_config(module) do
    [
      {:name, {:local, pool_name(module)}},
      {:worker_module, module},
      {:size, 5},
      {:max_overflow, 2}
    ]
  end

  def init(_) do
    children = [
      :poolboy.child_spec(PredictionWorker, poolboy_config(PredictionWorker)),
      :poolboy.child_spec(LearnerWorker, poolboy_config(LearnerWorker))
    ]

    Supervisor.init(children, strategy: :one_for_one, name: @name)
  end
end
