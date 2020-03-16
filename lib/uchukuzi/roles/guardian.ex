defmodule Uchukuzi.Roles.Guardian do
  @moduledoc """
  An individual who cares for a set of students typically a parent
  """
  alias __MODULE__

  @enforce_keys [:name, :email, :password]
  defstruct [:name, :email, :password]

  def new(name, email, password) do
    %Guardian{name: name, email: email, password: password}
  end
end
