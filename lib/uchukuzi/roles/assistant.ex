defmodule Uchukuzi.Roles.Assistant do
  @moduledoc """
  An employee of a school assigned to a bus who records the
  boarding and exiting of students from a bus
  """
  alias __MODULE__

  @enforce_keys [:name, :email, :password]
  defstruct [:name, :email, :password]

  def new(name, email, password) do
    %Assistant{name: name, email: email, password: password}
  end
end
