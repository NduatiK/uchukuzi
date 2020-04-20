defmodule Uchukuzi.School.Bus.FuelRecord do
  alias __MODULE__
  alias Uchukuzi.School.Bus

  @enforce_keys [:amount, :bus, :time]
  defstruct [:amount, :bus, :time]

  def new(%Bus{} = bus, time, amount) do
    %FuelRecord{bus: bus, time: time, amount: amount}
  end
end
