defmodule Uchukuzi.Roles.Manager do
  alias __MODULE__

  @enforce_keys [:name, :email, :password]
  defstruct [:name, :email, :password]

  @spec new(any, any, any) :: Uchukuzi.Roles.Manager.t()
  def new(name, email, password) do
    %Manager{name: name, email: email, password: password}
  end
end
