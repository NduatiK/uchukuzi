defmodule Uchukuzi.World.ETAGraph do
  @moduledoc """
  A struct used to represent a route graph with ETA data.
  """

  alias __MODULE__
  alias Uchukuzi.World.Tile

  defstruct [:links]

  defguardp valid_time(time) when time in [:evening, :morning]

  def new(),
    do: %ETAGraph{}

  def add_link(%ETAGraph{} = graph, %Tile{} = from, %Tile{} = to, time_inside_to, trip_time)
      when valid_time(trip_time) do
    update_link(graph, Tile.name(from), Tile.name(to), time_inside_to, trip_time)
  end

  def update_link(graph, from_name, to_name, time_inside_to, trip_time) do
    graph
    |> get_and_update_in([:links, from_name], fn x ->
      new_value = Map.new({to_name, {trip_time, time_inside_to}})

      if x == nil do
        {x, new_value}
      else
        {x, Map.merge(x, new_value)}
      end
    end)
  end

  
end
