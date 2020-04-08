defmodule Uchukuzi.School.Device do
  @moduledoc """
  The IoT device placed on a school bus to reports its location
  """
  use Uchukuzi.School.Model

  schema "devices" do
    field(:imei, :string)
    belongs_to(:bus, Bus)

    timestamps()
  end

  def new(params) do
    changeset(params)
  end

  def changeset(schema \\ %__MODULE__{}, params) do
    schema
    |> cast(params, [:imei, :bus_id])
    |> validate_required([:imei])
    |> validate_imei()
    |> unique_constraint(:imei)
  end

  defp validate_imei(changeset) do
    with %{imei: imei} <- changeset.changes,
         true <- is_valid_imei(imei) do
      changeset
    else
      _ ->
        Ecto.Changeset.add_error(changeset, :imei, "invalid imei format")
    end
  end

  @doc """
  Checks whether an imei string is valid.

  This is true when:
    - the luhn's sum of the imei is divisible by 10
    - the imei contains 15 or 17 digits
  ## Examples

  iex> Uchukuzi.School.Device.is_valid_imei("490154203237518")
  true

  iex> Uchukuzi.School.Device.is_valid_imei("49015420323751842")
  true

  iex> Uchukuzi.School.Device.is_valid_imei("49015420323751")
  false
  """
  @imei_lengths [15, 17]
  def is_valid_imei(imei) do
    is_valid_length = fn imei -> String.length(imei) in @imei_lengths end

    with {imei_number, ""} <- Integer.parse(imei),
         true <- is_valid_length.(imei),
         0 <- imei_number |> luhns_sum |> rem(10) do
      true
    else
      _ -> false
    end
  end

  @doc """
  Calculates the Luhn's sum of a integer

  The Luhn's sum is calculated by adding
    - the sum of all odd positioned digits (starting with the most significant as index 1)
    - the sum of all the digits double of the even positioned numbers

  The luhns sum of 1822 is 1 + (1 + 6) + 2 + (4)

  ## Examples

      iex> Uchukuzi.School.Device.luhns_sum(490154203237518)
      60

      iex> Uchukuzi.School.Device.luhns_sum(49015420323751842)
      70

      iex> Uchukuzi.School.Device.luhns_sum(4901542032375)
      50

      iex> Uchukuzi.School.Device.luhns_sum([4,9,0,1,5,4,2,0,3,2,3,7,5])
      50

      iex> Uchukuzi.School.Device.luhns_sum(0)
      0

      iex> Uchukuzi.School.Device.luhns_sum([0])
      0

  """
  def luhns_sum(int) when is_integer(int), do: Integer.digits(int) |> _luhns_sum(0, true)
  def luhns_sum(int_list) when is_list(int_list), do: _luhns_sum(int_list, 0, true)

  defp _luhns_sum([], sum, _), do: sum

  defp _luhns_sum([head | tail], sum, oddPosition = true) do
    _luhns_sum(tail, sum + head, !oddPosition)
  end

  defp _luhns_sum([head | tail], sum, oddPosition = false) do
    _luhns_sum(tail, sum + sum_of_double(head), !oddPosition)
  end

  def sum_of_double(x) do
    (x * 2)
    |> Integer.digits()
    |> Enum.sum()
  end
end
