defmodule Uchukuzi.School.Device do
  @moduledoc """
  The IoT device placed on a school bus to reports its location
  """
  @enforce_keys [:imei]
  defstruct [:imei]
end
