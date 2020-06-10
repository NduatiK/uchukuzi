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

  @message_timeout 3600 * 1_000
  # states
  @new :new
  @ongoing :ongoing
  @complete :complete

  import Ecto.Query

  use Uchukuzi.Tracking.Model

  def start_link(bus) do
    GenServer.start_link(__MODULE__, bus, name: via_tuple(bus))
  end

  @spec via_tuple(Uchukuzi.School.Bus.t()) :: {:via, Registry, {Uchukuzi.Registry, any}}
  defp via_tuple(%Bus{} = bus),
    do: Uchukuzi.service_name({__MODULE__, bus.id})

  @spec pid_from(Uchukuzi.School.Bus.t()) :: nil | pid | {atom, atom}
  def pid_from(%Bus{} = bus, retries \\ 0) do
    pid =
      bus
      |> via_tuple()
      |> GenServer.whereis()

    result =
      with nil <- pid do
        BusesSupervisor.start_bus(bus)

        bus
        |> via_tuple()
        |> GenServer.whereis()
      end

    if result == nil do
      if retries > 1 do
        nil
      else
        retries = retries + 1
        :timer.sleep(100 * retries)

        pid_from(bus, retries)
      end
    else
      result
    end
  end

  def init(bus) do
    school = Uchukuzi.Repo.preload(bus, :school).school

    # approximate the time_offset
    # Nairobi returns 2.45 instead of 3 which should be okay if we allow a margin of 2 hrs each way
    time_offset = 12 * (school.perimeter.center.lng / 180)

    data = %{
      bus_id: bus.id,
      route_id: bus.route_id,
      school: school,
      timezone: time_offset,
      trip: Trip.new(bus),
      trip_path: nil,
      state: @new,
      last_notified_tile: nil
    }

    {:ok, data}
  end

  def handle_call({:add_report, %Report{} = report}, _from, %{state: @new} = data) do
    if School.School.contains_point?(data.school, report.location) do
      # trips only start when we exit the school
      {:reply, :ok, data, @message_timeout}
    else
      data =
        data
        |> insert_trip_path_if_needed(report)
        |> insert_report(report)
        |> set_state(@ongoing)

      if data.trip.travel_time == "evening" do
        PubSub.publish(
          :trip_started,
          {:trip_started, data.route_id, Trip.students_onboard(data.trip)}
        )
      end

      {:reply, :ok, data, @message_timeout}
    end
  end

  def handle_call({:add_report, %Report{} = report}, _from, %{state: @ongoing} = data) do
    data =
      data
      |> insert_trip_path_if_needed(report)
      |> insert_report(report)

    if School.School.contains_point?(data.school, report.location) do
      {:stop, :normal, :ok, data |> set_state(@complete)}
    else
      {:reply, :ok, data, @message_timeout}
    end
  end

  def handle_call(:students_onboard, _from, data) do
    students = Trip.students_onboard(data.trip)
    {:reply, students, data, @message_timeout}
  end

  def handle_call(:ongoing_trip, _from, %{state: @ongoing} = data) do
    trip_with_deviation =
      data.trip
      |> Trip.set_deviation_positions(data.trip_path.deviation_positions)

    {:reply, trip_with_deviation, data, @message_timeout}
  end

  def handle_call(:ongoing_trip, _from, data) do
    {:reply, nil, data, @message_timeout}
  end

  def handle_cast({:student_boarded, activity}, data) do
    data =
      data
      |> insert_activity(activity)

    {:noreply, data, @message_timeout}
  end

  def handle_cast({:student_exited, activity}, data) do
    data =
      data
      |> insert_activity(activity)

    {:noreply, data, @message_timeout}
  end

  # provided `tiles` are in LRF order here
  # they are stored in MRF order
  def handle_cast({:crossed_tiles, []}, data) do
    {:noreply, data, @message_timeout}
  end

  def handle_cast({:crossed_tiles, tiles}, data) do
    #  is_in_student_trip = Enum.count(Trip.students_onboard(data.trip)) > 0
    # is_in_student_trip = data.trip.travel_time in Trip.travel_times()
    is_in_student_trip = true

    data =
      data
      |> insert_trip_path_if_needed()

    # with path when not is_nil(path) <- data.trip_path do
    # Match crossed tiles to historical tiles
    # • Find out what tiles need to be crossed
    # • Predict
    # • Report to tile members

    trip_path =
      if is_in_student_trip do
        trip_path =
          data.trip_path
          |> TripPath.crossed_tiles(tiles)
          |> TripPath.update_predictions(data.trip.end_time)

        keep_first = fn list ->
          list
          |> Enum.uniq_by(fn {tile, _time} -> tile end)
        end

        keep_last = fn list ->
          list
          |> Enum.reverse()
          |> keep_first.()
          |> Enum.reverse()
        end

        etas =
          if data.trip.travel_time == "evening" do
            trip_path.eta
            # |> keep_first.()
          else
            trip_path.eta
            # |> keep_last.()
          end

        PubSub.publish(
          :eta_prediction_update,
          {:eta_prediction_update, data.route_id, etas, Trip.students_onboard(data.trip)}
        )

        %{trip_path | eta: etas}
      else
        data.trip_path
        |> TripPath.crossed_tiles(tiles)
      end

    data = %{data | trip_path: trip_path}

    last_notified_tile = data.last_notified_tile

    data =
      case data.trip_path.eta do
        [] ->
          data

        [h | _] when h == last_notified_tile ->
          data

        [{new_next_tile, _eta} | _] ->
          PubSub.publish(
            :approaching_tile,
            {:approaching_tile, data.route_id, new_next_tile, data.trip.travel_time,
             Trip.students_onboard(data.trip)}
          )

          %{data | last_notified_tile: new_next_tile}
      end

    {:noreply, data, @message_timeout}
  end

  def handle_cast(:update_school, data) do
    school = Uchukuzi.Repo.get(Uchukuzi.School.School, data.school.id)
    data = %{data | school: school}

    {:noreply, data, @message_timeout}
  end

  def handle_info(:timeout, data) do
    {:stop, {:shutdown, :timeout}, data}
  end

  def handle_info(_, data) do
    {:noreply, data, @message_timeout}
  end

  def terminate(_reason, %{state: @complete} = data) do
    PubSub.publish(
      :trip_ended,
      {:trip_ended, data.route_id, Trip.students_onboard(data.trip)}
    )

    store_trip(data.trip, data.trip_path, data.timezone)
  end

  def terminate({:shutdown, :timeout}, %{state: @ongoing} = data) do
    store_trip(data.trip, data.trip_path, data.timezone)
  end

  # if stop when incomplete
  def terminate(_reason, _data) do
    # :ets.insert(tableName(), {data.bus_id, data})
  end

  def insert_trip_path_if_needed(data, report \\ nil)

  def insert_trip_path_if_needed(%{trip_path: nil} = data, report) do
    deviation_radius = data.school.deviation_radius

    expected_tiles =
    if data.route_id == nil do
      nil
    else
      Uchukuzi.School.Route
      |> where([r], r.id == ^data.route_id)
      |> Uchukuzi.Repo.one()
      |> (& &1.expected_tiles).()
    end

    IO.puts("TripPath.new")

    trip_path =
      if not is_nil(expected_tiles) do
        school_tile = Tile.new(data.school.perimeter.center).coordinate

        expected_tiles
        |> Enum.filter(&(&1 != school_tile))
        |> TripPath.new(deviation_radius)
        |> TripPath.update_predictions(report)
      else
        TripPath.new(nil, deviation_radius)
      end

    %{data | trip_path: trip_path}
  end

  def insert_trip_path_if_needed(data, _report), do: data

  def insert_report(data, report) do
    trip = data.trip |> Trip.insert_report(report, data.timezone)

    Task.async(fn ->
      if Enum.count(trip.report_collection.reports) == 1 do
        PubSub.publish(
          :trip_update,
          {:trip_update, data.bus_id, trip}
        )
      else
        PubSub.publish(
          :trip_update,
          {:trip_update, data.bus_id, report}
        )
      end
    end)

    %{data | trip: trip}
  end

  def set_state(data, @ongoing = state) do
    %{data | state: state}
  end

  def set_state(data, @complete = state) do
    %{data | state: state}
  end

  def set_state(data, _), do: data

  def insert_activity(data, activity) do
    PubSub.publish(
      :trip_update,
      {:trip_update, self(), data.bus_id, activity}
    )

    %{data | trip: data.trip |> Trip.insert_student_activity(activity)}
  end

  def store_trip(%Trip{} = trip, trip_path, timezone) do
    IO.inspect("store_trip")

    trip
    |> Trip.add_crossed_tiles(trip_path.consumed_tile_locs)
    |> Trip.clean_up_trip(timezone)
    |> Trip.set_deviation_positions(trip_path.deviation_positions)
    |> Repo.insert()
  end

  # *************************** CLIENT ***************************#

  def add_report(bus, report),
    do: call_tracker(bus, {:add_report, report})

  @spec student_boarded(Uchukuzi.School.Bus.t(), any) :: :ok
  def student_boarded(bus, student_activity),
    do: cast_tracker(bus, {:student_boarded, student_activity})

  def student_exited(bus, student_activity),
    do: cast_tracker(bus, {:student_exited, student_activity})

  def students_onboard(bus),
    do: call_tracker(bus, :students_onboard)

  def ongoing_trip(bus),
    do: call_tracker(bus, :ongoing_trip)

  # Expects tiles sorted first crossed to last crossed
  def crossed_tiles(bus, tiles),
    do: cast_tracker(bus, {:crossed_tiles, tiles})

  def update_school(bus) do
    # We use this cast to avoid creating buses
    bus
    |> via_tuple()
    |> GenServer.whereis()
    |> (fn
          nil ->
            nil

          server ->
            server |> GenServer.cast(:update_school)
        end).()
  end

  defp cast_tracker(bus, arguments) do
    bus
    |> pid_from()
    |> GenServer.cast(arguments)
  end

  defp call_tracker(bus, arguments) do
    bus
    |> pid_from()
    |> GenServer.call(arguments)
  end
end
