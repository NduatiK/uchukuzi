defmodule Uchukuzi.School.Bus.FuelReport do
  alias __MODULE__
  use Uchukuzi.School.Model

  schema "fuel_records" do
    field(:volume, :float)
    field(:cost, :integer)
    field(:date, :naive_datetime)
    field(:distance_travelled, :integer)
    belongs_to(:bus, Uchukuzi.School.Bus)
  end

  def changeset(schema \\ %__MODULE__{}, params) do
    params |> IO.inspect(label: "Uchukuzi.School.Bus.FuelReport")
    schema
    |> cast(params, [:cost, :volume, :bus_id, :date, :distance_travelled])
    |> validate_required([:cost, :volume, :bus_id, :date,:distance_travelled])
  end
end
