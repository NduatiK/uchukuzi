defmodule Uchukuzi.Tracking.BusServer do
  use GenServer

  alias Uchukuzi.School.Bus
  alias Uchukuzi.Common.Location
  alias Uchukuzi.School.School
  alias Uchukuzi.Common.Report
  alias Uchukuzi.Tracking.BusesSupervisor

  alias __MODULE__

  defmodule State do
    alias __MODULE__
    defstruct [:bus, :school, last_seen: nil, speed: 0, bearing: 0]

    def set_location(%State{} = state, %Report{} = report) do
      with last_seen when not is_nil(last_seen) <- state.last_seen,
           comparison when comparison in [:gt, :eq] <-
             DateTime.compare(report.time, last_seen.time) do
        d = Location.distance_between(report.location, last_seen.location) / 1000
        t = DateTime.diff(report.time, last_seen.time) / 3600
        s = if(t == 0, do: 0, else: d / t)

        bearing = Location.bearing(last_seen.location, report.location)

        bearing =
          if bearing < 0 do
            bearing + 360
          else
            bearing
          end

        %{
          state
          | last_seen: %{
              time: report.time,
              location: report.location
            },
            speed: s,
            bearing: bearing
        }
      else
        nil -> %{state | last_seen: report}
        :lt -> state
      end
    end

    @spec last_seen(Uchukuzi.Tracking.BusServer.State.t()) :: any
    def last_seen(%State{} = state) do
      with report when not is_nil(report) <- Map.get(state, :last_seen),
           speed when not is_nil(speed) <- Map.get(state, :speed),
           bearing when not is_nil(bearing) <- Map.get(state, :bearing) do
        %{
          speed: speed,
          time: report.time,
          location: report.location,
          bearing: bearing
        }
      else
        _ ->
          nil
      end
    end

    def bus(%State{} = state) do
      Map.get(state, :bus)
    end

    def in_school?(%State{} = state) do
      case {state.school, state.last_seen} do
        {_, nil} -> true
        {nil, _} -> true
        {school, _} -> School.contains_point?(school, state.last_seen.location)
      end
    end
  end

  @spec start_link(Uchukuzi.School.Bus.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%Bus{} = bus), do: GenServer.start_link(__MODULE__, bus, name: via_tuple(bus))

  def via_tuple(%Bus{} = bus),
    do: Uchukuzi.service_name({__MODULE__, bus.id})

  @spec pid_from(Uchukuzi.School.Bus.t()) :: nil | pid | {atom, atom}
  def pid_from(%Bus{} = bus) do
    with nil <-
           bus
           |> BusServer.via_tuple()
           |> GenServer.whereis() do
      BusesSupervisor.start_bus(bus)

      bus
      |> BusServer.via_tuple()
      |> GenServer.whereis()
    end
  end

  @impl true
  def init(%Bus{} = bus) do
    state = %State{
      bus: bus,
      school: Uchukuzi.Repo.preload(bus, :school).school
    }

    {:ok, state}
  end

  # *************************** CLIENT ***************************#

  def bus(bus_server),
    do: GenServer.cast(bus_server, {:bus})

  def move(bus_server, %Report{} = report),
    do: GenServer.call(bus_server, {:move, report})

  def last_seen_location(bus_server),
    do: GenServer.call(bus_server, :last_seen).location

  def last_seen_status(bus_server),
    do: GenServer.call(bus_server, :last_seen)

  def broadcast_location_data(bus_server),
    do: GenServer.call(bus_server, :broadcast_location_data)

  def in_school?(bus_server),
    do: GenServer.call(bus_server, :in_school?)

  # *************************** SERVER ***************************#

  @impl true
  def handle_call({:move, report}, _from, state) do
    state = State.set_location(state, report)

    if State.in_school?(state) do
      {:reply, state, state, :hibernate}
    else
      {:reply, state, state}
    end
  end

  def handle_call(:last_seen, _from, state) do
    {:reply, State.last_seen(state), state}
  end

  def handle_call(:broadcast_location_data, _from, state) do
    {:reply, State.last_seen(state), state}
  end

  def handle_call(:bus, _from, state) do
    {:reply, State.bus(state), state}
  end

  def handle_call(:in_school?, _from, state) do
    {:reply, State.in_school?(state), state}
  end
end