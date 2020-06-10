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

  def start_link(%Location{} = location) do
    GenServer.start_link(__MODULE__, Tile.new(location), name: via_tuple(location))
  end

  @impl true
  def init(%Tile{} = tile) do
    state = %{
      tile: tile,
      pids: %{}
    }

    {:ok, state}
  end

  def via_tuple(%Location{} = location),
    do: Uchukuzi.service_name({__MODULE__, location |> Tile.origin_of_tile()})

  @impl true
  def handle_call({:enter, pid, entry_time}, _from, state) do
    record = %{
      entry_time: entry_time,
      ref: Process.monitor(pid)
    }

    {:reply, :ok, put_in(state, [:pids, pid], record)}
  end

  @impl true
  def handle_call({:leave, pid, exit_time}, _from, state) do
    state =
      if state.pids[pid] != nil do
        WorldManager.crossed_tile(
          state.tile,
          pid,
          DateTime.diff(exit_time, state.pids[pid].entry_time),
          state.pids[pid].entry_time
        )

        remove(state, pid)
      else
        state
      end

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
    if state.pids[pid] != nil do
      Process.demonitor(state.pids[pid].ref)
    end

    %{state | pids: Map.delete(state.pids, pid)}
  end
end
