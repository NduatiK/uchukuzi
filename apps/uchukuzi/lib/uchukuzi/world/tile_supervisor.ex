defmodule Uchukuzi.World.TileSupervisor do
  use DynamicSupervisor

  alias Uchukuzi.World.TileServer
  alias Uchukuzi.World.Tile
  alias Uchukuzi.Common.Location

  @name __MODULE__

  def start_link(_options) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  ################ SERVER ################

  @spec tile_for(Uchukuzi.Common.Location.t()) :: pid | {atom, node} | nil
  defp tile_for(%Location{} = location) do
    with nil <- GenServer.whereis(TileServer.via_tuple(location)) do
      with {:ok, child} <-
             DynamicSupervisor.start_child(
               __MODULE__,
               {TileServer, location}
             ) do
        child
      else
        {:error, {:already_started, pid}} ->
          pid
      end
    end
  end

  defp call_cell(%Tile{} = tile, arguments) do
    tile.coordinate
    |> tile_for()
    |> GenServer.cast(arguments)
  end

  ################ CLIENT ################

  def enter(pid, tile, entry_time),
    do: call_cell(tile, {:enter, pid, entry_time})

  def leave(pid, tile, exit_time),
    do: call_cell(tile, {:leave, pid, exit_time})

end
