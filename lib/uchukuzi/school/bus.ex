defmodule Uchukuzi.School.Bus do
  use Uchukuzi.School.Model

  @vehicle_types ~w(van shuttle bus)
  @fuel_types ~w(gasoline diesel)

  schema "buses" do
    field(:name, :string)

    field(:number_plate, :string)
    field(:seats_available, :integer)
    field(:vehicle_type, :string)

    # Km / L
    field(:stated_milage, :float)
    field(:fuel_type, :string)

    belongs_to(:school, School)
    has_one(:device, Device)
    has_many(:trips, Uchukuzi.Tracking.Trip)

    timestamps()
  end

  def new(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(schema, params) do
    schema
    |> cast(params, __MODULE__.__schema__(:fields))
    |> validate_required([:number_plate, :vehicle_type, :stated_milage, :fuel_type])
    |> validate_inclusion(:vehicle_type, @vehicle_types)
    |> validate_number(:seats_available, greater_than: 3, less_than: 100)
    |> validate_inclusion(:fuel_type, @fuel_types)
    |> trim_number_plate()
    |> Validation.validate_number_plate()
    |> unique_constraint(:number_plate, name: :buses_school_id_number_plate_index)
  end

  def trim_number_plate(changeset) do
    case changeset do
      %Ecto.Changeset{changes: %{number_plate: number_plate}} ->
        put_change(changeset, :number_plate, String.replace(number_plate, ~r/\s/, ""))

      _ ->
        changeset
    end
  end
end
