defmodule Uchukuzi.School.Bus.PerformedRepair do
  alias __MODULE__
  alias Uchukuzi.School.Bus
  @enforce_keys [:bus, :cost, :part, :time]
  defstruct [:bus, :cost, :part, :time]

  def new(%Bus{} = bus, cost, part, time) do
    %PerformedRepair{
      bus: bus,
      cost: cost,
      part: part,
      time: time
    }
  end
end
