defmodule Uchukuzi.Tracking.TripSupervisor do
  use DynamicSupervisor

  alias Uchukuzi.Tracking.TripTracker
  alias Uchukuzi.Report
  alias Uchukuzi.School.Bus
  alias Uchukuzi.School.School

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

  @spec start_trip(
          __MODULE__.t(),
          Uchukuzi.School.School.t(),
          Uchukuzi.School.Bus.t(),
          Uchukuzi.Report.t()
        ) :: :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
  def start_trip(trip_supervisor, %School{} = school, %Bus{} = bus, %Report{} = initial_report) do
    args = %{
      school: school,
      bus: bus,
      initial_report: initial_report,
      geofences: []
    }

    DynamicSupervisor.start_child(
      trip_supervisor,
      {TripTracker, [args, bus]}
    )
  end
end
