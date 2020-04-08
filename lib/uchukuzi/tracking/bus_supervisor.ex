defmodule Uchukuzi.Tracking.BusSupervisor do
  use Supervisor, restart: :transient

  alias Uchukuzi.School.Bus
  alias Uchukuzi.Tracking.BusServer
  alias Uchukuzi.Tracking.TripSupervisor

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
