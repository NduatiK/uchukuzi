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
  alias Uchukuzi.Tracking.StudentActivity
  alias Uchukuzi.Tracking.BusesSupervisor

  alias Uchukuzi.Common.Report
  alias Uchukuzi.School.School
  alias Uchukuzi.School.Bus

  def start_link(bus) do
    GenServer.start_link(__MODULE__, bus, name: via_tuple(bus))
  end

  def init(bus) do
    data = %{
      bus_id: bus.id,
      school: Uchukuzi.Repo.preload(bus, :school).school,
      trip: Trip.new(bus),
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
      data = %{
        data
        | trip: Trip.insert_report(data.trip, report),
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

  # tiles are first crossed to last crossed here
  def handle_cast({:crossed_tiles, tiles}, data) do
    data =
      case {data.trip.crossed_tiles, tiles} do
        #  If the tiles overlap, ignore the first new tile
        {[h | _], [h | tail]} ->
          %{
            data
            | trip: %{data.trip | crossed_tiles: Enum.reverse(tail) ++ data.trip.crossed_tiles}
          }

        #  Otherwise just add it
        _ ->
          %{
            data
            | trip: %{data.trip | crossed_tiles: Enum.reverse(tiles) ++ data.trip.crossed_tiles}
          }
      end

    {:noreply, data, @message_timeout}
  end

  def handle_info(:timeout, data) do
    {:stop, {:shutdown, :timeout}, %{data | state: :complete}}
  end

  def terminate(_reason, %{state: :complete} = data) do
    data = %{data | trip: Trip.clean_up_trip(data.trip)}
    Uchukuzi.Repo.insert(data.trip)
    :ets.delete(tableName(), data.bus_id)
  end

  def terminate({:shutdown, :timeout}, data) do
    data = %{data | trip: Trip.clean_up_trip(data.trip)}
    Uchukuzi.Repo.insert(data.trip)
    :ets.delete(tableName(), data.bus_id)
  end

  # if stop when incomplete
  def terminate(_reason, data) do
    IO.puts("# TODO - No")
    :ets.insert(tableName(), {data.bus_id, data})
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

  defp cast_tracker(bus, arguments) do
    bus
    |> pid_from()
    |> GenServer.cast(arguments)
  end
end
