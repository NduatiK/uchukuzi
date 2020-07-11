defmodule Uchukuzi.Common.Validation do
  import Ecto.Changeset

  def phone_number_regex, do: ~r/^(?:254|\+254|0)?(7[0-9]{8})$/

  # Reference: Facebook Login iOS SDK
  def email_regex, do: ~r/([A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4})/

  def number_plate_regex do
    letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    {:ok, reg} = Regex.compile("^K[#{letters}]{2}\\d{3}[#{letters}]{0,1}$")
    reg
  end

  @doc ~S"""
  Match valid Kenyan phone numbers
  """
  def validate_phone_number(changeset, field \\ :phone_number) do
    changeset
    |> validate_format(field, phone_number_regex())
  end

  @spec validate_email(Ecto.Changeset.t(), atom) :: Ecto.Changeset.t()
  def validate_email(changeset, field \\ :email) do
    changeset
    |> validate_format(field, email_regex())
  end

  def validate_number_plate(changeset, field \\ :number_plate) do
    changeset
    |> validate_format(field, number_plate_regex())
  end
end
