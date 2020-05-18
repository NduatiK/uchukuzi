defmodule Uchukuzi.Common.Report do
  alias __MODULE__

  alias Uchukuzi.Common.Location
  use Ecto.Schema

  embedded_schema do
    embeds_one(:location, Location)

    field(:time, :utc_datetime)
    field(:bearing, :float, default: 0)
    field(:speed, :float, default: 0)
  end

  def new(time, %Location{} = location) do
    %Report{time: time, location: location}
  end

  def is_report(%__MODULE__{}), do: true
  def is_report(_), do: false

  def to_report(%{location: %Location{} = location, time: time}), do: new(time, location)

  def to_coord(%{location: %Location{} = location}),
    do: Location.to_coord(location)
end
