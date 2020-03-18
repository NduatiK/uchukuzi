defmodule Uchukuzi.Tracking.TripTracker do
  use GenServer, restart: :transient

  @message_timeout 60 * 15 * 1_000

  alias Uchukuzi.School.School
  alias Uchukuzi.School.Bus
  alias Uchukuzi.Tracking.Report
  alias Uchukuzi.Tracking.Trip
  alias Uchukuzi.Tracking.Geofence
  alias Uchukuzi.Tracking.StudentActivity

  def start_link(
        %{
          school: %School{} = school,
          bus: %Bus{} = bus,
          initial_report: %Report{},
          geofences: geofences
        } = args
      )
      when is_list(geofences) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(school, bus))
  end

  def via_tuple(%School{} = school, %Bus{} = bus),
    do: {:via, Registry, {Registry.Uchukuzi, "#{school.name}:#{bus.number_plate}"}}

  def fresh_state(%{
        school: %School{} = school,
        bus: %Bus{} = bus,
        initial_report: %Report{} = initial_report,
        geofences: geofences
      }) do
    %{
      name: via_tuple(school, bus),
      trip: Trip.new(initial_report, school),
      school: school,
      geofences: geofences,
      violations: []
    }
  end

  def init(
        %{
          school: %School{} = school,
          bus: %Bus{} = bus
        } = args
      ) do
    send(self(), {:set_state, via_tuple(school, bus), args})

    {:ok, fresh_state(args), @message_timeout}
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

  def trip(trip_tracker) do
    GenServer.call(trip_tracker, :trip)
  end

  # Server
  def handle_cast({:insert_report, report}, state) do
    state
    |> update_trip_with(report)
    |> update_geofence_violations(report)
    |> exit_with_save()

    # TODO: calculate distance covered
    # TODO: calculate fuel consumed
  end

  def handle_cast({:insert_student_activity, student_activity}, state) do
    state
    |> update_trip_with(student_activity)
    |> send_notification_of_student_activity()
    |> exit_with_save()
  end

  def handle_call(:current_location, _from, state) do
    {:reply, Trip.latest_location(state.trip), state}
  end

  def handle_call(:students_onboard, _from, state) do
    {:reply, Trip.students_onboard(state.trip), state}
  end

  def handle_call(:trip, _from, state) do
    {:reply, state.trip, state}
  end

  defp exit_with_save(state) do
    :ets.insert(tableName(), {state.name, state})

    cond do
      Trip.is_terminated(state.trip) ->
        state = %{state | trip: Trip.end_trip(state.trip)}
        {:stop, {:shutdown, :completed_trip}, state}

      true ->
        {:noreply, state, @message_timeout}
    end
  end

  def handle_info(:timeout, state) do
    {:stop, {:shutdown, :timeout}, state}
  end

  def handle_info({:set_state, name, args}, _state) do
    state =
      case :ets.lookup(tableName(), name) do
        [] -> fresh_state(args)
        [{_key, state}] -> state
      end

    {:noreply, state, @message_timeout}
  end

  def terminate({:shutdown, reason}, state) when reason in [:timeout, :completed_trip] do
    :ets.delete(tableName(), state.name)
    :ok
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp update_trip_with(state, %Report{} = report) do
    case Trip.insert_report(state.trip, report, state.school) do
      {:ok, trip} ->
        %{state | trip: trip}

      {:error, :invalid_report_for_trip} ->
        state
    end
  end

  defp update_trip_with(state, %StudentActivity{} = activity) do
    case Trip.insert_student_activity(state.trip, activity) do
      {:ok, trip} ->
        %{state | trip: trip}

      {:error, :activity_out_of_trip_bounds} ->
        state
    end
  end

  defp update_geofence_violations(state, %Report{} = report) do
    violations =
      state.geofences
      |> Enum.filter(&Geofence.contains_point?(&1, report.location))

    %{state | violations: violations ++ state.violations}
  end

  defp send_notification_of_student_activity(
         %{trip: %Trip{student_activities: [activity | _]}} = state
       ) do
    if not inside_school?(state.school, activity.infered_location) do
      # TODO: send activiy notification (through a delegate)
    end

    state
  end

  defp send_notification_of_student_activity(state) do
  end

  defp inside_school?(school, location) do
    Geofence.contains_point?(school.perimeter, location)
  end

  def tableName, do: :active_trips
end
