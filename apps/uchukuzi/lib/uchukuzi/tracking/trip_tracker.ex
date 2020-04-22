defmodule Uchukuzi.Tracking.TripTracker do
  use GenServer, restart: :transient

  @moduledoc """

  States
  1. `new` - used when a `TripTracker` is created,
  indicates that no reports have been received since the
  last trip was closed

  2. `ongoing` - used when a `TripTracker` is created,
  indicates that no reports have been received since the
  last trip was closed

  """

  @message_timeout 60 * 60 * 1_000

  alias Uchukuzi.Tracking.Trip
  alias Uchukuzi.Tracking.TripPath
  alias Uchukuzi.Tracking.StudentActivity
  alias Uchukuzi.Tracking.BusesSupervisor

  alias Uchukuzi.Common.Report
  alias Uchukuzi.School.School
  alias Uchukuzi.School.Bus

  import Ecto.Query

  def start_link(bus) do
    GenServer.start_link(__MODULE__, bus, name: via_tuple(bus))
  end

  def init(bus) do
    data = %{
      bus_id: bus.id,
      school: Uchukuzi.Repo.preload(bus, :school).school,
      trip: Trip.new(bus),
      trip_path: nil,
      state: :new
    }

    {:ok, data}
  end

  @spec via_tuple(Uchukuzi.School.Bus.t()) :: {:via, Registry, {Uchukuzi.Registry, any}}
  def via_tuple(%Bus{} = bus),
    do: Uchukuzi.service_name({__MODULE__, bus.id})

  def tableName, do: :active_trips

  @spec pid_from(Uchukuzi.School.Bus.t()) :: nil | pid | {atom, atom}
  def pid_from(%Bus{} = bus) do
    pid =
      bus
      |> __MODULE__.via_tuple()
      |> GenServer.whereis()

    with nil <- pid do
      BusesSupervisor.start_bus(bus)

      bus
      |> __MODULE__.via_tuple()
      |> GenServer.whereis()
    end
  end

  def handle_cast({:add_report, %Report{} = report}, %{state: :new} = data) do
    if School.contains_point?(data.school, report.location) do
      {:noreply, data}
    else
      startedTrip =
        data.trip
        |> Trip.insert_report(report)
        |> Trip.infer_trip_travel_time()

      similarTrip =
        Trip
        |> where([t], t.bus_id == ^data.bus_id and t.travel_time == ^startedTrip.travel_time)
        |> Ecto.Query.first(desc_nulls_last: :start_time)
        |> Uchukuzi.Repo.one()

      trip_path =
        with trip when not is_nil(trip) <- similarTrip do
          trip.crossed_tiles
          |> TripPath.new()
          |> TripPath.update_predictions()
        end

      data = %{
        data
        | trip: startedTrip,
          state: :ongoing
      }

      {:noreply, data, @message_timeout}
    end
  end

  def handle_cast({:add_report, %Report{} = report}, %{state: :ongoing} = data) do
    data = %{data | trip: Trip.insert_report(data.trip, report)}

    if School.contains_point?(data.school, report.location) do
      {:stop, :normal, %{data | state: :complete}}
    else
      {:noreply, data, @message_timeout}
    end
  end

  def handle_cast({:student_boarded, %StudentActivity{} = activity}, data) do
    data = %{data | trip: Trip.insert_student_activity(data.trip, activity)}

    {:noreply, data, @message_timeout}
  end

  def handle_cast({:student_exited, %StudentActivity{} = activity}, data) do
    data = %{data | trip: Trip.insert_student_activity(data.trip, activity)}
    {:noreply, data, @message_timeout}
  end

  # provided `tiles` are in LRF order here
  # they are stored in MRF order
  def handle_cast({:crossed_tiles, tiles}, data) do
    is_in_student_trip = Enum.member?(Trip.travel_times(), data.trip.travel_time)

    if is_in_student_trip do
      trip_path =
        with path when not is_nil(path) <- data.trip_path do
          # Match crossed tiles to historical tiles
          # • Find out what tiles need to be crossed
          # • Predict
          # • Report to tile members

          path =
            path
            |> TripPath.crossed_tiles(tiles)
            |> TripPath.update_predictions()

          PubSub.publish(:prediction_update, {self(), data.bus_id, path.eta})

          path
        end

      # UchukuziInterfaceWeb.Endpoint.broadcast("school:#{school_id}", "bus_moved", output)
      %{data | trip_path: trip_path}
    end

    {:noreply, data, @message_timeout}
  end

  def handle_call(:students_onboard, _from, data) do
    students = Trip.students_onboard(data.trip)
    {:reply, students, data, @message_timeout}
  end

  def handle_info(:timeout, data) do
    {:stop, {:shutdown, :timeout}, %{data | state: :complete}}
  end

  def terminate(_reason, %{state: :complete} = data) do
    data = %{data | trip: Trip.clean_up_trip(data.trip)}
    Uchukuzi.Repo.insert(data.trip)
    # :ets.delete(tableName(), data.bus_id)
  end

  def terminate({:shutdown, :timeout}, data) do
    data = %{data | trip: Trip.clean_up_trip(data.trip)}
    Uchukuzi.Repo.insert(data.trip)
    # :ets.delete(tableName(), data.bus_id)
  end

  # if stop when incomplete
  def terminate(_reason, data) do
    IO.puts("# TODO - No")
    # :ets.insert(tableName(), {data.bus_id, data})
  end

  # *************************** CLIENT ***************************#

  def add_report(bus, report),
    do: cast_tracker(bus, {:add_report, report})

  # Expects tiles sorted first crossed to last crossed
  def crossed_tiles(bus, tiles),
    do: cast_tracker(bus, {:crossed_tiles, tiles})

  def student_boarded(bus, student_activity),
    do: cast_tracker(bus, {:student_boarded, student_activity})

  def student_exited(bus, student_activity),
    do: cast_tracker(bus, {:student_exited, student_activity})

  def students_onboard(bus) do
    bus
    |> pid_from()
    |> GenServer.call(:students_onboard)
  end

  defp cast_tracker(bus, arguments) do
    bus
    |> pid_from()
    |> GenServer.cast(arguments)
  end
end
