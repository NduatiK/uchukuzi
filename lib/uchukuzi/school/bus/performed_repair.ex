defmodule Uchukuzi.School.Bus.PerformedRepair do
  alias __MODULE__
  use Uchukuzi.School.Model

  schema "performed_repairs" do
    field(:cost, :float)
    field(:part, :string)
    field(:description, :string, size: 500)

    belongs_to(:bus, Uchukuzi.School.Bus)

    timestamps()
  end

  def changeset(schema \\ %__MODULE__{}, params) do
    schema
    |> cast(params, [:cost, :part, :bus_id, :description])
    |> validate_required([:cost, :part, :bus_id])
    |> validate_inclusion(:part, valid_parts())
    |> validate_length(:description, max: 500)
  end

  def valid_parts() do
    [
      "Front Left Tire",
      "Front Right Tire",
      "Rear Left Tire",
      "Rear Right Tire",
      "Engine",
      "Front Cross Axis",
      "Rear Cross Axis",
      "Vertical Axis"
    ]
  end
end
