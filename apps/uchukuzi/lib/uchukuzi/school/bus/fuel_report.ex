defmodule Uchukuzi.School.Bus.FuelReport do
  alias __MODULE__
  use Uchukuzi.School.Model

  schema "fuel_records" do
    field(:volume, :float)
    field(:trips_made, :integer)
    field(:cost, :integer)
    field(:date, :naive_datetime)
    field(:distance_travelled, :integer)
    belongs_to(:bus, Uchukuzi.School.Bus)
  end

  def changeset(schema \\ %__MODULE__{}, params) do

    schema
    |> cast(params, [:cost, :volume, :bus_id, :date, :distance_travelled, :trips_made])
    |> validate_required([:cost, :volume, :bus_id, :date,:distance_travelled, :trips_made])
  end
end
