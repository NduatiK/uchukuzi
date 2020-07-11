defmodule ValidationTest do
  use ExUnit.Case
  use PropCheck
  alias Uchukuzi.Common.Validation

  test "validation of emails" do
    assert is_valid_email("email@example.com")
    assert is_valid_email("john.doe@example.com")
    assert is_valid_email("john123@example.com")
    assert is_valid_email("a@b.co")

    refute is_valid_email("email@example")
    refute is_valid_email("@example")
    refute is_valid_email("@example.com")
    refute is_valid_email("a@b")
    refute is_valid_email("a@b.")
    refute is_valid_email("a@b.c")
  end

  def is_valid_email(string), do: Regex.match?(Validation.email_regex(), string)

  test "validation of phone_numbers" do
    assert is_valid_phone_no("0719801234")

    refute is_valid_phone_no("07198012a4")
    refute is_valid_phone_no("07198012344")
    refute is_valid_phone_no("071980124")
  end


  def is_valid_phone_no(string), do: Regex.match?(Validation.phone_number_regex(), string)

  test "validation of number plates" do
    assert is_valid_number_plate("KAB123L")
    assert is_valid_number_plate("KZZ321")

    refute is_valid_number_plate("KAB123O")
    refute is_valid_number_plate("KAB123I")

    refute is_valid_number_plate("KZZ32")
    refute is_valid_number_plate("KZZ32")
  end

  def is_valid_number_plate(string), do: Regex.match?(Validation.number_plate_regex(), string)
end
