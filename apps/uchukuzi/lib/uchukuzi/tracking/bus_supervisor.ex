defmodule Uchukuzi.Tracking.BusSupervisor do
  use Supervisor, restart: :transient

  alias Uchukuzi.School.Bus
  alias Uchukuzi.Tracking.BusServer
  alias Uchukuzi.Tracking.TripTracker

  def start_link(bus) do
    Supervisor.start_link(__MODULE__, bus, name: via_tuple(bus))
  end

  def via_tuple(%Bus{} = bus),
    do: Uchukuzi.service_name({__MODULE__, bus.id})

  def init(bus) do
    children = [
      worker(BusServer, [bus]),
      worker(TripTracker, [bus])
    ]

    # if Mix.env() == :dev do
      Supervisor.init(children, strategy: :one_for_one, max_restarts: 20_000)
    # else
    #   Supervisor.init(children, strategy: :one_for_one)
    # end
  end
end
