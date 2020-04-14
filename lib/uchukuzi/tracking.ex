defmodule Uchukuzi.Tracking do
  @moduledoc """
  Used to report all real-world events

  It
  * 1. Triggers location updates within the system

  * 2. Calls into the World Context to provide ETA information

   Trips are created for two reasons:
   1. When the bus leaves the school
   2. When the assistant begins taking attendance of students boarding the bus
  """

  alias Uchukuzi.School.Bus

  alias Uchukuzi.Roles.CrewMember
  alias Uchukuzi.Roles.Student

  alias Uchukuzi.Tracking
  alias Uchukuzi.Tracking.TripTracker
  alias Uchukuzi.Tracking.BusServer

  alias Uchukuzi.Common.Report

  alias Uchukuzi.World

  def student_boarded(%Bus{} = bus, %Student{} = student, %CrewMember{} = assistant) do
    bus
    |> TripTracker.pid_from()
    |> TripTracker.student_boarded(student, assistant)
  end

  def move(%Bus{} = bus, %Report{} = report) do
    # IO.inspect(report)
    bus_server = BusServer.pid_from(bus)

    previous_report = BusServer.last_seen_status(bus_server)

    # Only perform World updates when the bus is outside school,
    # This avoids tracking its presence in the school as being inside a tile for a long time
    # if not in_school?(bus) do
    if previous_report == nil or DateTime.compare(report.time, previous_report.time) == :gt do
      World.update(bus_server, previous_report, report)
    end

    # else
    #   IO.puts("inschool")
    # end

    BusServer.move(bus_server, report)
    # IO.puts("----")
    # TODO: Where do trips come in?
  end

  def status_of(%Bus{} = bus) do
    bus
    |> BusServer.pid_from()
    |> BusServer.last_seen_status()
  end

  def where_is(%Bus{} = bus) do
    bus
    |> BusServer.pid_from()
    |> BusServer.last_seen_location()
  end

  def in_school?(%Bus{} = bus) do
    bus_server = BusServer.pid_from(bus)
    BusServer.in_school?(bus_server)
  end

  def add_location_to_buses(buses) do
    buses
    |> Enum.map(&{1, Tracking.where_is(&1)})
    |> Enum.map(fn {bus, location} ->
      %{bus: bus.id, loc: if(is_nil(location), do: nil, else: location)}
    end)
  end
end
