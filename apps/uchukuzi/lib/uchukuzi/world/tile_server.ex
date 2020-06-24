defmodule Uchukuzi.World.TileServer do
  use GenServer, restart: :transient

  @moduledoc """
  This module keeps track of which vehicles are in a specific `Tile`
  and, once the bus leaves, reports on how long it took to cross the tile.

  The tile is born when a bus crosses into its region and
  dies when it no longer hosts any buses.
  """

  alias Uchukuzi.Common.Location
  alias Uchukuzi.World.Tile
  alias Uchukuzi.World.WorldManager

  def start_link(%Location{} = location) do
    GenServer.start_link(__MODULE__, Tile.new(location), name: via_tuple(location))
  end

  @impl true
  def init(%Tile{} = tile) do
    # pids here refers to the bus servers that have
    # reported that their bus is in the tile
    state = %{
      tile: tile,
      pids: %{}
    }

    {:ok, state}
  end

  def via_tuple(%Location{} = location),
    do: Uchukuzi.service_name({__MODULE__, location |> Tile.new() |> (& &1.coordinate).()})

  @impl true
  def handle_call({:enter, pid, entry_time}, _from, state) do
    record = %{
      entry_time: entry_time,
      ref: Process.monitor(pid)
    }

    updated_state =
      state
      |> put_in([:pids, pid], record)

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:leave, pid, exit_time}, _from, state) do
    cross_time = DateTime.diff(exit_time, state.pids[pid].entry_time)

    updated_state =
      state
      |> report_cross_time(pid, cross_time)
      |> remove(pid)

    if state.pids == %{} do
      {:stop, :normal, :ok, state}
    else
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # If the bus server dies somehow, stop monitoring it.
    {:noreply, remove(state, pid)}
  end

  def handle_info(_, _) do
    # Handle other info messages
  end

  defp remove(state, pid) do
    if state.pids[pid] != nil do
      Process.demonitor(state.pids[pid].ref)
    end

    %{state | pids: Map.delete(state.pids, pid)}
  end

  defp report_cross_time(state, pid, cross_time) do
    if state.pids[pid] != nil do
      WorldManager.crossed_tile(
        state.tile,
        pid,
        cross_time,
        state.pids[pid].entry_time
      )
    end

    state
  end
end
