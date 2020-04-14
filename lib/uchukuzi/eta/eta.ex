defmodule Uchukuzi.World.ETARecord do
  @moduledoc """
  A struct used to represent a route graph with ETA data.
  """

  alias __MODULE__
  alias Uchukuzi.World.Tile

  defstruct [
    :date,
    :entry_time,
    :bearing,
    :speed,
    :temperature
  ]
end
