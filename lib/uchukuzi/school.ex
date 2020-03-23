defmodule Uchukuzi.School do
  alias Uchukuzi.School.Bus
  alias Uchukuzi.School.BusServer
  alias Uchukuzi.Common.Report
  alias Uchukuzi.World

  def move(%Bus{} = bus, %Report{} = report) do
    bus_server = BusServer.pid_from(bus)

    previous_report = BusServer.last_seen(bus_server) || report


    # TODO: Where do trips come in?
    BusServer.move(bus_server, report)

    World.update(bus_server, previous_report, report)
  end
end
