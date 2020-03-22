defmodule Uchukuzi.School.Bus do
  alias __MODULE__

  alias Uchukuzi.School.Device
  alias Uchukuzi.School.Route
  alias Uchukuzi.Roles.Assistant

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
end
