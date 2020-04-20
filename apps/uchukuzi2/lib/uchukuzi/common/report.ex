defmodule Uchukuzi.Common.Report do
  alias __MODULE__

  alias Uchukuzi.Common.Location
  use Ecto.Schema

  embedded_schema do
    field(:time, :utc_datetime)
    embeds_one(:location, Location)
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
