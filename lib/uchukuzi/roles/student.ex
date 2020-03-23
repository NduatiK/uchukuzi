defmodule Uchukuzi.Roles.Student do
  @travel_times ~w(morning evening two_way)
  @moduledoc """
  An school bus user who attends a specific school.

  A student may be registered to use the bus in the
  morning and/or evening (#{
    Enum.reduce(@travel_times, &(&2 <> ", " <> &1)) |> String.replace_suffix(",", "")
  })

  A student may be granted access to bus details by their `Guardian`
  """
  alias __MODULE__

  @enforce_keys [:name, :travel_time]
  defstruct [:name, :email, :password, :travel_time]

  def new(name, travel_time) when travel_time in @travel_times,
    do: %Student{name: name, travel_time: travel_time}

  def is_student(%Student{}), do: true
  def is_student(_), do: false
end
