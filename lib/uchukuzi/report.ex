defmodule Uchukuzi.Report do
  alias __MODULE__

  alias Uchukuzi.Location

  @enforce_keys [:time, :location]
  defstruct [:time, :location]
  @type t :: %__MODULE__{time: Int.t(), location: Location.t()}

  def new(time, %Location{} = location) do
    %Report{time: time, location: location}
  end

  def is_report(%__MODULE__{}), do: true
  def is_report(_), do: false

  def to_coord(%Report{} = report),
    do: Location.to_coord(report.location)
end
