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
  def pid_from(%Bus{} = bus) do
    pid =
      bus
      |> via_tuple()
      |> GenServer.whereis()

    with nil <- pid do
      BusesSupervisor.start_bus(bus)

      bus
      |> via_tuple()
      |> GenServer.whereis()
    end
  end

  def init(bus) do
    data = %{
      bus_id: bus.id,
      route_id: bus.route_id,
      school: Uchukuzi.Repo.preload(bus, :school).school,
      trip: Trip.new(bus),
      trip_path: nil,
      state: @new
    }

    {:ok, data}
  end

  def handle_cast({:add_report, %Report{} = report}, %{state: @new} = data) do
    if School.School.contains_point?(data.school, report.location) do
      # trips only start when we exit the school
      {:noreply, data}
    else
      report = %{report | speed: 0, bearing: 0}

      data =
        data
        |> insert_trip_path(report)
        |> insert_report(report)
        |> set_state(@ongoing)

      {:noreply, data, @message_timeout}
    end
  end

  def handle_cast({:add_report, %Report{} = report}, %{state: @ongoing} = data) do
    data =
      data
      |> insert_trip_path(report)
      |> insert_report(report)

    if School.School.contains_point?(data.school, report.location) do
      IO.inspect(report.location)
      IO.inspect("School.contains_point")
      {:stop, :normal, data |> set_state(@complete)}
    else
      {:noreply, data, @message_timeout}
    end
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
    is_in_student_trip = Enum.member?(Trip.travel_times(), data.trip.travel_time)

    data =
      data
      |> insert_trip_path()

    # if true do
    # if is_in_student_trip do
    # with path when not is_nil(path) <- data.trip_path do
    # Match crossed tiles to historical tiles
    # • Find out what tiles need to be crossed
    # • Predict
    # • Report to tile members
    # path =
    trip_path =
      data.trip_path
      |> TripPath.crossed_tiles(tiles)
      |> TripPath.update_predictions(data.trip.end_time)

    PubSub.publish(
      :eta_prediction_update,
      {:eta_prediction_update, self(), data.route_id, trip_path.eta}
    )

    # path
    # IO.inspect("as", label: "Received")

    #   path
    # end

    # UchukuziInterfaceWeb.Endpoint.broadcast("school:#{school_id}", "bus_moved", output)
    # else
    #   data.trip_path
    # end

    data = %{data | trip_path: trip_path}

    {:noreply, data, @message_timeout}
  end

  def handle_call(:students_onboard, _from, data) do
    students = Trip.students_onboard(data.trip)
    {:reply, students, data, @message_timeout}
  end

  def handle_info(:timeout, data) do
    {:stop, {:shutdown, :timeout}, data}
  end

  def terminate(_reason, %{state: @complete} = data) do
    store_trip(data.trip, data.trip_path)
  end

  def terminate({:shutdown, :timeout}, %{state: @ongoing} = data) do
    store_trip(data.trip, data.trip_path)
  end

  # if stop when incomplete
  def terminate(_reason, _data) do
    # :ets.insert(tableName(), {data.bus_id, data})
  end

  def insert_trip_path(data, report \\ nil)

  def insert_trip_path(%{trip_path: nil} = data, report) do
    similarTrip =
      Trip
      # |> where([t], t.bus_id == ^data.bus_id and t.travel_time == ^startedTrip.travel_time)
      |> where([t], t.bus_id == ^data.bus_id)
      |> Ecto.Query.first(desc_nulls_last: :start_time)
      |> Uchukuzi.Repo.one()

    IO.puts("TripPath.new")

    trip_path =
      with trip when not is_nil(trip) <- similarTrip do
        trip.crossed_tiles
        |> TripPath.new()
        |> TripPath.update_predictions(report)
      else
        _ ->
          TripPath.new(nil)
      end

    %{data | trip_path: trip_path}
  end

  def insert_trip_path(data, _report), do: data

  def insert_report(data, report) do
    %{data | trip: data.trip |> Trip.insert_report(report)}
  end

  def set_state(data, @ongoing = state) do
    %{data | state: state}
  end

  def set_state(data, @complete = state) do
    %{data | state: state}
  end

  def set_state(data, _), do: data

  def insert_activity(data, activity) do
    %{data | trip: data.trip |> Trip.insert_student_activity(activity)}
  end

  def store_trip(%Trip{} = trip, trip_path) do
    {reports, trip} =
      %Trip{trip | crossed_tiles: trip_path.consumed_tile_locs}
      |> Trip.clean_up_trip()
      |> Map.pop(:reports, [])

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:trip, trip)
    |> Ecto.Multi.merge(fn %{trip: trip} ->
      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :reports,
        Ecto.build_assoc(trip, :report_collection)
        |> (fn collection ->
              %ReportCollection{
                collection
                | reports: reports,
                  deviation_positions: trip_path.deviation_positions
              }
            end).()
      )
    end)
    |> Repo.transaction()
  end

  # *************************** CLIENT ***************************#

  def add_report(bus, report),
    do: cast_tracker(bus, {:add_report, report})

  @spec student_boarded(Uchukuzi.School.Bus.t(), any) :: :ok
  def student_boarded(bus, student_activity),
    do: cast_tracker(bus, {:student_boarded, student_activity})

  def student_exited(bus, student_activity),
    do: cast_tracker(bus, {:student_exited, student_activity})

  def students_onboard(bus) do
    bus
    |> pid_from()
    |> GenServer.call(:students_onboard)
  end

  # Expects tiles sorted first crossed to last crossed
  def crossed_tiles(bus, tiles),
    do: cast_tracker(bus, {:crossed_tiles, tiles})

  defp cast_tracker(bus, arguments) do
    bus
    |> pid_from()
    |> GenServer.cast(arguments)
  end
end
