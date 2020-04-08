defmodule Uchukuzi.World.WorldSupervisor do
  use Supervisor

  @name __MODULE__
  alias Uchukuzi.World.WorldManager
  alias Uchukuzi.World.TileSupervisor
  alias Uchukuzi.World.WeatherAPI

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def init(_) do
    children = [
      worker(WeatherAPI, [[]]),
      worker(WorldManager, [[]]),
      supervisor(TileSupervisor, [[]])
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
