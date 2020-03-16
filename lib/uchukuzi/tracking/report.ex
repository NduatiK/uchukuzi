defmodule Uchukuzi.Tracking.Report do
  alias __MODULE__

  alias Uchukuzi.Location
  alias Uchukuzi.School.Device

  @enforce_keys [:time, :location, :device]
  defstruct [:time, :location, :device]

  def new(time, %Location{} = location, %Device{} = device) do
    %Report{time: time, location: location, device: device}
  end

  def is_report(%__MODULE__{}), do: true
  def is_report(_), do: false
end
