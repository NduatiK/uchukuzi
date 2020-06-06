defmodule Uchukuzi.Tracking do
  @moduledoc """
  Used to report all real-world events

  It
  * 1. Triggers location updates within the system

  * 2. Calls into the World Context to provide ETA information

   Trips are created when the bus leaves the school
  """

  alias Uchukuzi.School.Bus

  alias Uchukuzi.Roles.CrewMember
  alias Uchukuzi.Roles.Student

  use Uchukuzi.Tracking.Model

  alias Uchukuzi.Common.Report
  alias Uchukuzi.World

  def student_boarded(%Bus{} = bus, %Student{} = student, %CrewMember{} = assistant) do
    student_activity = StudentActivity.boarded(student, assistant)
    TripTracker.student_boarded(bus, student_activity)
  end

  def move(%Bus{} = bus, %Report{} = report) do
    bus_server = BusServer.pid_from(bus)

    previous_report = BusServer.last_seen_status(bus_server)

    # Update the bus location, speed, beaering...
    BusServer.move(bus_server, report)

    # Simulate the bus moving through the world
    # Return the tiles it crossed through
    tiles = World.update(bus_server, previous_report, report)

    # And let it know which tiles have been crossed so far so
    # that it can try to predict the future
    TripTracker.crossed_tiles(bus, tiles |> Enum.map(fn x -> x.coordinate end))
  end

  def status_of(%Bus{} = bus) do
    bus
    |> BusServer.pid_from()
    |> BusServer.last_seen_status()
    |> add_bus(bus)
  end

  def add_bus(nil, _), do: nil

  def add_bus(last_seen, bus),
    do:
      last_seen
      |> Map.put(:bus, bus.id)

  def students_onboard(%Bus{} = bus) do
    TripTracker.students_onboard(bus)
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

  def trip_for(school_id, trip_id) do
    Repo.one(
      from(t in Trip,
        join: b in assoc(t, :bus),
        where: b.school_id == ^school_id and t.id == ^trip_id,
        preload: [bus: b]
      )
    )
  end

  def ongoing_trip_for(%Bus{} = bus) do
    bus
    |> TripTracker.ongoing_trip()
  end
end
