defmodule Uchukuzi.School.Bus.FuelRecord do
  alias __MODULE__
  use Uchukuzi.School.Model

  schema "fuel_records" do
    field(:volume, :float)
    field(:cost, :integer)
    field(:date, :naive_datetime)
    belongs_to(:bus, Uchukuzi.School.Bus)
  end

  def changeset(schema \\ %__MODULE__{}, params) do
    schema
    |> cast(params, [:cost, :volume, :bus_id, :date])
    |> validate_required([:cost, :volume, :bus_id, :date])
  end
end
