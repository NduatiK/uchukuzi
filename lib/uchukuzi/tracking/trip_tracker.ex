defmodule Uchukuzi.Tracking.TripTracker do
  # use GenServer, restart: :transient
  use GenServer

  @message_timeout 60 * 15 * 1_000

  alias __MODULE__

  alias Uchukuzi.Roles.Student
  alias Uchukuzi.Roles.CrewMember

  alias Uchukuzi.Common.Report
  alias Uchukuzi.Common.Geofence

  alias Uchukuzi.School.Bus
  alias Uchukuzi.Tracking.Trip
  alias Uchukuzi.Tracking.StudentActivity

  def start_link([args, %Bus{} = bus]) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(bus))
  end

  def via_tuple(%Bus{} = bus),
    do: Uchukuzi.service_name({__MODULE__, bus.id})

  def pid_from(%Bus{} = bus) do
    bus
    |> via_tuple()
    |> GenServer.whereis()
  end

  def fresh_state(%{
        bus: %Bus{} = bus,
        initial_report: %Report{} = report
      }) do
    %{
      name: via_tuple(bus),
      trip: Trip.new() |> insert_report(report),
      school_perimeter: bus.school.perimeter
    }
  end

  def fresh_state(%{
        bus: %Bus{} = bus,
        student_activity: %StudentActivity{} = activity
      }) do
    %{
      name: via_tuple(bus),
      trip: Trip.new() |> Trip.insert_student_activity(activity),
      school_perimeter: bus.school.perimeter
    }
  end

  def init(%{bus: %Bus{} = bus} = args) do
    send(self(), {:set_state, via_tuple(bus), args})

    {:ok, fresh_state(args), :hibernate}
  end

  # *********************** Client API *********************** #
  def insert_report(trip_tracker, %Report{} = report),
    do: GenServer.cast(trip_tracker, {:insert_report, report})

  def student_boarded(trip_tracker, %Student{} = student, %CrewMember{role: "assistant"} = assistant),
    do: GenServer.cast(trip_tracker, {:student_boarded, student, assistant})

  def student_exited(trip_tracker, %Student{} = student, %CrewMember{role: "assistant"} = assistant),
    do: GenServer.cast(trip_tracker, {:student_exited, student, assistant})

  # def current_location(trip_tracker) do
  #   GenServer.call(trip_tracker, :current_location)
  # end

  # def students_onboard(trip_tracker) do
  #   GenServer.call(trip_tracker, :students_onboard)
  # end

  # def trip(trip_tracker) do
  #   GenServer.call(trip_tracker, :trip)
  # end

  # Server

  # *********************** Server API *********************** #
  def handle_cast({:student_boarded, student, assistant}, state) do
    student_activity = student |> StudentActivity.boarded(assistant)

    state
    |> update_trip_with(student_activity)
    |> send_notification_of_student_activity()
    |> exit_with_save()
  end

  def handle_cast({:student_exited, student, assistant}, state) do
    student_activity = StudentActivity.exited(student, assistant)

    state
    |> update_trip_with(student_activity)
    |> send_notification_of_student_activity()
    |> exit_with_save()
  end

  def handle_cast({:insert_report, report}, state) do
    state
    |> update_trip_with(report)
    # |> update_geofence_violations(report)
    |> exit_with_save()

    # TODO: calculate distance covered
    # TODO: calculate fuel consumed
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

    {:noreply, state, :hibernate}
  end

  def terminate({:shutdown, reason}, state) when reason in [:timeout, :completed_trip] do
    :ets.delete(tableName(), state.name)
    :ok
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp update_trip_with(state, %Report{} = report) do
    case Trip.insert_report(state.trip, report, state.school_perimeter) do
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

  # defp update_geofence_violations(state, %Report{} = report) do
  #   violations =
  #     state.geofences
  #     |> Enum.filter(&Geofence.contains_point?(&1, report.location))

  #   %{state | violations: violations ++ state.violations}
  # end

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
