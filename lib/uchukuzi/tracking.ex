defmodule Uchukuzi.Tracking do
  @moduledoc """
  Used to report all real-world events

   Trips are created for two reasons:
   1. When the bus leaves the school
   2. When the assistant begins taking attendance of students boarding the bus
  """

  alias Uchukuzi.School.Bus

  alias Uchukuzi.Roles.Assistant
  alias Uchukuzi.Roles.Student

  alias Uchukuzi.Tracking
  alias Uchukuzi.Tracking.TripTracker
  alias Uchukuzi.Tracking.BusServer

  alias Uchukuzi.Common.Report

  alias Uchukuzi.World

  def student_boarded(%Bus{} = bus, %Student{} = student, %Assistant{} = assistant) do
    bus
    |> TripTracker.pid_from()
    |> TripTracker.student_boarded(student, assistant)
  end

  def move(%Bus{} = bus, %Report{} = report) do
    bus_server = BusServer.pid_from(bus)

    previous_report = BusServer.last_seen(bus_server) || report

    # TODO: Where do trips come in?
    BusServer.move(bus_server, report)

    # World.update(bus_server, previous_report, report)
  end

  def where_is(%Bus{} = bus) do
    bus
    |> BusServer.pid_from()
    |> BusServer.last_seen()
  end

  def in_school?(%Bus{} = bus) do
    bus_server = BusServer.pid_from(bus)
    BusServer.in_school?(bus_server)
  end

  def add_location_to_buses(buses) do
    buses
    |> Enum.map(
      &{
        &1,
        Tracking.where_is(&1)
      }
    )
    |> Enum.map(fn {bus, report} ->
      %{
        bus: bus.id,
        loc: if(is_nil(report), do: nil, else: report.location)
      }
    end)
    |> IO.inspect()
  end
end
