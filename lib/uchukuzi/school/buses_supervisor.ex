defmodule Uchukuzi.School.BusesSupervisor do
  use DynamicSupervisor

  alias Uchukuzi.School.Bus
  alias Uchukuzi.School.BusSupervisor

  def start_link(_options) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_bus(%Bus{} = bus) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {BusSupervisor, bus}
    )
  end
end
