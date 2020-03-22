defmodule Uchukuzi.School.BusSupervisor do
  use Supervisor, restart: :transient

  alias Uchukuzi.Tracking.TripSupervisor
  alias Uchukuzi.School.Bus
  alias Uchukuzi.School.BusServer

  def start_link(bus) do
    Supervisor.start_link(__MODULE__, bus, name: via_tuple(bus))
  end

  def via_tuple(%Bus{} = bus),
    do: Uchukuzi.service_name({__MODULE__, bus.id})

  def init(bus) do
    children = [
      worker(BusServer, [bus]),
      supervisor(TripSupervisor, [bus])
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
