defmodule Uchukuzi.Tracking.BusesSupervisor do
  use DynamicSupervisor

  alias Uchukuzi.School.Bus
  alias Uchukuzi.Tracking.BusSupervisor

  def start_link(_options) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_bus(%Bus{} = bus),
   do: start_bus(bus.id)

  def start_bus(bus_id) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {BusSupervisor, bus_id}
    )
  end
end
