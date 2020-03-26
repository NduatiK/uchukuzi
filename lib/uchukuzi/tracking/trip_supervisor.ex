defmodule Uchukuzi.Tracking.TripSupervisor do
  use DynamicSupervisor

  alias Uchukuzi.Tracking.TripTracker
  alias Uchukuzi.Tracking.StudentActivity
  alias Uchukuzi.Common.Report
  alias Uchukuzi.School.Bus


  def start_link(bus) do
    DynamicSupervisor.start_link(__MODULE__, bus, name: via_tuple(bus))
  end

  def via_tuple(%Bus{} = bus),
    do: Uchukuzi.service_name({__MODULE__, bus.id})

  def pid_from(%Bus{} = bus) do
    bus
    |> via_tuple()
    |> GenServer.whereis()
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_trip(trip_supervisor, %Bus{} = bus, %Report{} = initial_report) do
    args = %{
      bus: bus,
      initial_report: initial_report
    }

    start_child(trip_supervisor, args, bus)
  end

  def start_trip(trip_supervisor, %Bus{} = bus, %StudentActivity{} = activity) do
    args = %{
      bus: bus,
      student_activity: activity
    }

    start_child(trip_supervisor, args, bus)
  end

  def start_child(trip_supervisor, args, bus) do
    DynamicSupervisor.start_child(
      trip_supervisor,
      {TripTracker, [args, bus]}
    )
  end
end
