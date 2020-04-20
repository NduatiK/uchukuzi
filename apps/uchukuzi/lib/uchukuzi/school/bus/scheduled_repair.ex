defmodule Uchukuzi.School.Bus.ScheduledRepair do
  alias __MODULE__
  alias Uchukuzi.School.Bus
  @enforce_keys [:bus, :minimum_distance, :minimum_time, :time_created]
  defstruct [:bus, :minimum_distance, :minimum_time, :time_created]

  def new(%Bus{} = bus, minimum_distance, minimum_time, time_created) do
    %ScheduledRepair{
      minimum_distance: minimum_distance,
      minimum_time: minimum_time,
      bus: bus,
      time_created: time_created
    }
  end
end
