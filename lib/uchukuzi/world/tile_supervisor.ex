defmodule Uchukuzi.World.TileSupervisor do
  use DynamicSupervisor

  alias Uchukuzi.World.TileServer
  alias Uchukuzi.World.Tile
  alias Uchukuzi.Location

  @name __MODULE__

  def start_link(_options) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def tile_for(%Location{} = location) do
    with nil <- GenServer.whereis(TileServer.via_tuple(location)) do
      {:ok, child} =
        DynamicSupervisor.start_child(
          __MODULE__,
          {TileServer, location}
        )

      child
    end
  end

  def tile_for(%Tile{} = tile),
    do: tile_for(tile.coordinate)
end
