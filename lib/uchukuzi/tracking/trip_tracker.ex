defmodule Uchukuzi.Tracking.TripTracker do
  use GenServer

  alias Uchukuzi.School.School
  alias Uchukuzi.School.Bus
  alias Uchukuzi.Tracking.Report
  alias Uchukuzi.Tracking.Trip
  alias Uchukuzi.Tracking.Geofence
  alias Uchukuzi.Tracking.StudentActivity

  def start_link(%School{} = school, %Bus{} = bus, %Report{} = initial_report, geofences) do
    name = "#{school.name}:#{bus.number_plate}"
    GenServer.start_link(__MODULE__, {school, bus, initial_report, geofences}, name: name)
  end

  def init({%School{} = school, %Bus{} = _bus, %Report{} = initial_report, geofences}) do
    state = %{
      trip: Trip.new(initial_report, school),
      school: school,
      geofences: geofences,
      violations: []
    }

    {:ok, state}
  end

  # Client API
  def insert_report(trip_tracker, %Report{} = report) do
    # TODO: Ensure report belongs to this bus
    GenServer.cast(trip_tracker, {:insert_report, report})
  end

  def insert_student_activity(trip_tracker, %StudentActivity{} = student_activity) do
    # TODO: Ensure activity belongs to this bus
    GenServer.cast(trip_tracker, {:insert_student_activity, student_activity})
  end

  def current_location(trip_tracker) do
    GenServer.call(trip_tracker, :current_location)
  end

  def students_onboard(trip_tracker) do
    GenServer.call(trip_tracker, :students_onboard)
  end

  # Server
  def handle_cast({:insert_report, report}, state) do
    state
    |> update_trip_with(report)
    |> update_geofence_violations(report)
    # TODO: calculate distance covered
    # TODO: calculate fuel consumed
    |> exit_with_save()
  end

  def handle_cast({:insert_student_activity, student_activity}, state) do
    state
    |> update_trip_with(student_activity)
    |> send_notification_of(student_activity)
    |> exit_with_save()
  end

  def handle_call(:current_location, state) do
    {:reply, Trip.latest_location(state.trip), state}
  end
  def handle_call(:students_onboard, state) do
    {:reply, Trip.students_onboard(state.trip), state}
  end
  def exit_with_save(state) do
    cond do
      Trip.is_terminated(state.trip) ->
        state = %{state | trip: Trip.end_trip(state.trip)}
        {:stop, :normal, :ok, state}

      true ->
        {:noreply, state}
    end
  end

  def update_trip_with(state, %Report{} = report) do
    %{state | trip: Trip.insert_report(state.trip, report, state.school)}
  end

  def update_trip_with(state, %StudentActivity{} = activity) do
    %{state | trip: Trip.insert_student_activity(state.trip, activity)}
  end

  def update_geofence_violations(state, %Report{} = report) do
    violations =
      state.geofences
      |> Enum.filter(&Geofence.contains_point?(&1, report.location))

    %{state | violations: violations ++ state.violations}
  end

  def send_notification_of(state, %StudentActivity{} = activity) do
    if not inside_school?(state.school, activity.infered_location) do
      # TODO: send activiy notification (through a delegate)
    end

    state
  end

  def inside_school?(school, location) do
    Geofence.contains_point?(school.perimeter, location)
  end
end
