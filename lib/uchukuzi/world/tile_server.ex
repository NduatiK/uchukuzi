defmodule Uchukuzi.World.TileServer do
  use GenServer, restart: :transient

  @moduledoc """
  A `TileServer` is a process that keeps track of geographical regions
  in the real world as they relate to the location of vehicles
  """

  # alias __MODULE__
  alias Uchukuzi.Common.Location
  alias Uchukuzi.World.Tile
  alias Uchukuzi.World.TileSupervisor
  alias Uchukuzi.World.WorldManager
  alias Uchukuzi.Tracking.BusServer

  def start_link(%Location{} = location) do
    GenServer.start_link(__MODULE__, Tile.new(location).coordinate, name: via_tuple(location))
  end

  @impl true
  @spec init(Uchukuzi.Common.Location.t()) ::
          {:ok, %{pids: %{}, location: Uchukuzi.Common.Location.t()}}
  def init(%Location{} = location) do
    state = %{
      location: location,
      pids: %{}
    }

    {:ok, state}
  end

  def via_tuple(%Location{} = location),
    do: Uchukuzi.service_name({__MODULE__, location |> Tile.origin_of_tile()})

  @impl true
  def handle_call({:join, pid, report}, _from, state) do
    record = %{
      location: report.location,
      entry_time: report.time,
      ref: Process.monitor(pid)
    }

    # IO.inspect(self())
    # IO.inspect(record, label: "join")

    {:reply, :ok, put_in(state, [:pids, pid], record)}
  end

  @impl true
  def handle_call({:enter, pid, entry_time, location}, _from, state) do
    record = %{
      location: location,
      entry_time: entry_time,
      ref: Process.monitor(pid)
    }

    # IO.inspect(self())
    # IO.inspect(record, label: "enter")

    {:reply, :ok, put_in(state, [:pids, pid], record)}
  end

  @impl true
  def handle_call({:move, pid, report}, _from, state) do
    # IO.inspect(self())
    # IO.inspect(state.pids, label: "move")

    {
      :reply,
      :ok,
      put_in(state, [:pids, pid, :location], report.location)
    }
  end

  @impl true
  def handle_call({:leave, pid, exit_time}, _from, state) do
    # IO.inspect(self())
    # IO.inspect(state.pids, label: "leave")

    WorldManager.crossed_tile(
      Tile.new(state.location),
      pid,
      DateTime.diff(exit_time, state.pids[pid].entry_time),
      state.pids[pid].entry_time
    )

    state = remove(state, pid)

    if state.pids == %{} do
      {:stop, :normal, :ok, state}
    else
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, remove(state, pid)}
  end

  defp remove(state, pid) do
    Process.demonitor(state.pids[pid].ref)

    %{state | pids: Map.delete(state.pids, pid)}
  end
end
