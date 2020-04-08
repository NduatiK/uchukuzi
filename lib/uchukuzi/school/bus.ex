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

  # @enforce_keys [:id, :number_plate, :device, :route, :assistants]
  # defstruct [
  #   :id,
  #   :number_plate,
  #   :device,
  #   :route,
  #   assistants: [],
  #   fuel_records: [],
  #   performed_repairs: [],
  #   scheduled_repairs: []
  # ]

  # @spec new(any, Uchukuzi.School.Device.t(), Uchukuzi.School.Route.t()) ::
  # {:error, <<_::64, _::_*8>>} | {:ok, Uchukuzi.School.Bus.t()}
  # def new(number_plate, %Device{} = device, %Route{} = route) do
  #   with :ok <- validate_number_plate(number_plate) do
  #     {:ok,
  #      %Bus{
  #        id: number_plate,
  #        number_plate: number_plate,
  #        device: device,
  #        route: route,
  #        assistants: [],
  #        fuel_records: [],
  #        performed_repairs: [],
  #        scheduled_repairs: []
  #      }}
  #   else
  #     {:error, msg} ->
  #       {:error, msg}
  #   end
  # end

  def assign_assistant(%Bus{} = bus, %Assistant{} = assistant) do
    # %Bus{bus | assistants: [assistant | bus.assistants]}
  end

  def remove_assistant(%Bus{} = bus, %Assistant{} = assistant) do
    # %Bus{bus | assistants: Enum.filter(bus.assistants, &(&1 != assistant))}
  end

  @spec set_device(Uchukuzi.School.Bus.t(), Uchukuzi.School.Device.t()) :: Uchukuzi.School.Bus.t()
  def set_device(%Bus{} = bus, %Device{} = device) do
    # %Bus{bus | device: device}
  end

  def remove_device(%Bus{} = bus, %Device{} = device) do
    # if bus.device == device do
    #   {:ok, %Bus{bus | device: device}}
    # end

    # {:error, :wrong_device}
  end

  def add_fuel_record(%Bus{} = bus, %FuelRecord{} = record) do
    # %Bus{bus | fuel_records: [record | bus.fuel_records]}
  end

  def delete_fuel_record(%Bus{} = bus, %FuelRecord{} = record) do
    # %Bus{bus | fuel_records: Enum.filter(bus.fuel_records, &(&1 != record))}
  end

  def schedule_maintenance(%Bus{} = bus, %ScheduledRepair{} = schedule) do
    # %Bus{bus | scheduled_repairs: [schedule | bus.scheduled_repairs]}
  end

  def unschedule_maintenance(%Bus{} = bus, %ScheduledRepair{} = schedule) do
    # %Bus{bus | scheduled_repairs: Enum.filter(bus.scheduled_repairs, &(&1 != schedule))}
  end

  def add_maintenance_record(%Bus{} = bus, %PerformedRepair{} = record) do
    # %Bus{bus | performed_repairs: [record | bus.performed_repairs]}
  end

  def delete_maintenance_record(%Bus{} = bus, %PerformedRepair{} = record) do
    # %Bus{bus | performed_repairs: Enum.filter(bus.performed_repairs, &(&1 != record))}
  end
end
