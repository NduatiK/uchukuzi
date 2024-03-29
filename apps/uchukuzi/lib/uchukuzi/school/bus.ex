defmodule Uchukuzi.School.Bus do
  use Uchukuzi.School.Model

  @vehicle_types ~w(van shuttle bus)

  schema "buses" do
    field(:number_plate, :string)
    field(:seats_available, :integer)
    field(:vehicle_type, :string)

    belongs_to(:school, School)
    belongs_to(:route, Route)
    has_one(:device, Device)
    has_many(:trips, Uchukuzi.Tracking.Trip)
    has_many(:performed_repairs, PerformedRepair)
    has_many(:fuel_reports, FuelReport)

    timestamps()
  end

  def new(params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(schema, params) do
    schema
    |> cast(params, __MODULE__.__schema__(:fields))
    |> validate_required([:number_plate, :vehicle_type])
    |> validate_inclusion(:vehicle_type, @vehicle_types)
    |> validate_number(:seats_available, greater_than: 3, less_than: 100)
    |> trim_number_plate()
    |> Validation.validate_number_plate()
    |> unique_constraint(:number_plate, name: :buses_school_id_number_plate_index)
  end

  def trim_number_plate(changeset) do
    case changeset do
      %Ecto.Changeset{changes: %{number_plate: number_plate}} ->
        changeset
        |> put_change(:number_plate, String.replace(number_plate, ~r/\s/, ""))

      _ ->
        changeset
    end
  end

  @doc """
  Given a `bus` and a `date`
  Determine the total distance and number of trips
    made by that bus before that date
  """
  def distance_travelled_before(bus, date) do
    date = NaiveDateTime.to_date(date)

    result =
      Repo.all(
        from(b in Bus,
          left_join: t in assoc(b, :trips),
          where: fragment("?::date", t.end_time) <= ^date and b.id == ^bus.id,
          select: {type(sum(t.distance_covered), :float), count(t)}
        )
      )

    case result do
      [{nil, trips}] -> {0, trips}
      [{value, trips}] -> {round(value), trips}
    end
  end
end
