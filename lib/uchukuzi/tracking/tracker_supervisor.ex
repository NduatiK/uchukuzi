defmodule Uchukuzi.Tracking.TripTrackerSupervisor do
  use DynamicSupervisor

  alias Uchukuzi.Tracking.TripTracker
  alias Uchukuzi.Tracking.Report
  alias Uchukuzi.School.Bus
  alias Uchukuzi.School.School

  def start_link(_options) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_trip(
          Uchukuzi.School.School.t(),
          Uchukuzi.School.Bus.t(),
          Uchukuzi.Tracking.Report.t()
        ) :: :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
  def start_trip(%School{} = school, %Bus{} = bus, %Report{} = initial_report) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {TripTracker, %{school: school, bus: bus, initial_report: initial_report, geofences: []}}
    )
  end

  defp pid_from(%School{} = school, %Bus{} = bus) do
    TripTracker.via_tuple(school, bus)
    |> GenServer.whereis()
  end
end
