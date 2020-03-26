defmodule Uchukuzi.School.Bus do
  alias __MODULE__
  use Uchukuzi.School.Model

  @enforce_keys [:id, :number_plate, :device, :route, :assistants]
  defstruct [
    :id,
    :number_plate,
    :device,
    :route,
    assistants: [],
    fuel_records: [],
    performed_repairs: [],
    scheduled_repairs: []
  ]

  @spec new(any, Uchukuzi.School.Device.t(), Uchukuzi.School.Route.t()) ::
          {:error, <<_::64, _::_*8>>} | {:ok, Uchukuzi.School.Bus.t()}
  def new(number_plate, %Device{} = device, %Route{} = route) do
    with :ok <- validate_number_plate(number_plate) do
      {:ok,
       %Bus{
         id: number_plate,
         number_plate: number_plate,
         device: device,
         route: route,
         assistants: [],
         fuel_records: [],
         performed_repairs: [],
         scheduled_repairs: []
       }}
    else
      {:error, msg} ->
        {:error, msg}
    end
  end

  defp validate_number_plate(number_plate) when is_binary(number_plate) do
    invalid_characters = ["I", "O"]

    contains_invalid_characters =
      invalid_characters
      |> Enum.any?(&String.contains?(number_plate, &1))

    if contains_invalid_characters do
      {:error, "should not contain any letter in #{invalid_characters}"}
    end

    {:ok, reg} = Regex.compile("^K[A-Z]{2}\\d{3}[A-Z]{0,1}$")

    if Regex.match?(reg, number_plate) do
      :ok
    else
      {:error, "The number plate \"#{number_plate}\" has an invalid format"}
    end
  end

  defp validate_number_plate(garbage) do
    {:error, "A number plate should be a string, you gave a #{garbage}"}
  end

  def assign_assistant(%Bus{} = bus, %Assistant{} = assistant) do
    %Bus{bus | assistants: [assistant | bus.assistants]}
  end

  def remove_assistant(%Bus{} = bus, %Assistant{} = assistant) do
    %Bus{bus | assistants: Enum.filter(bus.assistants, &(&1 != assistant))}
  end

  @spec set_device(Uchukuzi.School.Bus.t(), Uchukuzi.School.Device.t()) :: Uchukuzi.School.Bus.t()
  def set_device(%Bus{} = bus, %Device{} = device) do
    %Bus{bus | device: device}
  end

  def remove_device(%Bus{} = bus, %Device{} = device) do
    if bus.device == device do
      {:ok, %Bus{bus | device: device}}
    end

    {:error, :wrong_device}
  end

  def add_fuel_record(%Bus{} = bus, %FuelRecord{} = record) do
    %Bus{bus | fuel_records: [record | bus.fuel_records]}
  end

  def delete_fuel_record(%Bus{} = bus, %FuelRecord{} = record) do
    %Bus{bus | fuel_records: Enum.filter(bus.fuel_records, &(&1 != record))}
  end

  def schedule_maintenance(%Bus{} = bus, %ScheduledRepair{} = schedule) do
    %Bus{bus | scheduled_repairs: [schedule | bus.scheduled_repairs]}
  end

  def unschedule_maintenance(%Bus{} = bus, %ScheduledRepair{} = schedule) do
    %Bus{bus | scheduled_repairs: Enum.filter(bus.scheduled_repairs, &(&1 != schedule))}
  end

  def add_maintenance_record(%Bus{} = bus, %PerformedRepair{} = record) do
    %Bus{bus | performed_repairs: [record | bus.performed_repairs]}
  end

  def delete_maintenance_record(%Bus{} = bus, %PerformedRepair{} = record) do
    %Bus{bus | performed_repairs: Enum.filter(bus.performed_repairs, &(&1 != record))}
  end
end
