defmodule Uchukuzi.World.TileServer do
  use GenServer, restart: :transient

  @moduledoc """
  A `TileServer` is a process that keeps track of geographical regions
  in the real world as they relate to the location of vehicles
  """

  # alias __MODULE__
  alias Uchukuzi.Common.Location
  alias Uchukuzi.World.Tile
  alias Uchukuzi.World.WorldManager
  alias Uchukuzi.School.BusServer

  defmodule BusState do
    @enforce_keys [:pid, :enter_time, :position, :ref]
    defstruct [:pid, :enter_time, :position, :ref]
  end

  def start_link(%Location{} = location) do
    GenServer.start_link(__MODULE__, Tile.new(location).coordinate, name: via_tuple(location))
  end

  @impl true
  @spec init(Uchukuzi.Common.Location.t()) :: {:ok, %{buses: %{}, location: Uchukuzi.Common.Location.t()}}
  def init(%Location{} = location) do
    state = %{
      location: location,
      buses: %{}
    }

    {:ok, state}
  end

  def via_tuple(%Location{} = location),
    do: Uchukuzi.service_name({__MODULE__, location |> Tile.origin_of_tile()})

  def moved(tile_server, bus_pid, current_report) do
    GenServer.cast(tile_server, {:moved, bus_pid, current_report})
  end

  def entered(tile_server, bus_pid, exit_time, location) do
    GenServer.cast(tile_server, {:entered, bus_pid, exit_time, location})
  end

  def exited(tile_server, bus_pid, exit_time) do
    GenServer.cast(tile_server, {:exited, bus_pid, exit_time})
  end

  def crossed(tile_server, bus_pid, average_time) do
    GenServer.cast(tile_server, {:crossed, bus_pid, average_time})
  end

  @impl true
  def handle_cast({:moved, bus_pid, current_report}, state) do
    with bus_state when bus_state != nil <- Map.get(state.buses, bus_pid),
         true <- bus_state.enter_time < current_report.time do
      bus_state = %{
        bus_state
        | position: current_report.location
      }

      state
      |> put_in([:buses, bus_pid], bus_state)
      |> save_state()
    else
      # First appearance in grid
      nil ->
        bus_state = %BusState{
          pid: bus_pid,
          enter_time: current_report.time,
          position: current_report.location,
          ref: Process.monitor(bus_pid)
        }

        state
        |> put_in([:buses, bus_pid], bus_state)
        |> save_state()

      # Late message
      false ->
        state |> save_state()
    end
  end

  @impl true
  def handle_cast({:exited, bus_pid, exit_time}, state) do
    time_inside = exit_time - state.buses[bus_pid].enter_time

    # TODO: Learn
    # IO.inspect(time_inside, label: "#{self()}: time_inside")

    # Uchukuzi.ETA.time_in(self(), bus_pid, time_inside)
    state
    |> remove(bus_pid)
    |> save_state()
  end

  @impl true
  def handle_cast({:entered, bus_pid, entry_time, location}, state) do
    bus_state = %BusState{
      pid: bus_pid,
      enter_time: entry_time,
      position: location,
      ref: Process.monitor(bus_pid)
    }

    state
    |> put_in([:buses, bus_pid], bus_state)
    |> save_state()
  end

  @impl true
  def handle_cast({:crossed, bus_pid, average_time}, state) do
    # TODO: Learn
    bus = BusServer.bus(bus_pid)
    WorldManager.bus_crossed_tile(bus, state.tile, average_time)
    # .time_in(self(), bus_pid, average_time)
    IO.inspect(average_time, label: "cross time")

    state
    |> save_state()
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, bus, _reason}, state) do
    state
    |> remove(bus)
    |> save_state()
  end

  defp remove(state, bus) do
    Process.demonitor(state.buses[bus].ref)

    %{state | buses: Map.delete(state.buses, bus)}
  end

  def save_state(state) do
    if state.buses == %{} do
      # Die when empty
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end
end
