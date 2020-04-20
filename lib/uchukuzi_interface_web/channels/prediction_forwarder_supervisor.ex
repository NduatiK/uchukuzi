defmodule UchukuziInterfaceWeb.PredictionForwarderSupervisor do
  @moduledoc """
  
  """
  use Supervisor

  @name __MODULE__


  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def init(_) do
    children = [
      worker(UchukuziInterfaceWeb.PredictionForwarder, [[]])
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
