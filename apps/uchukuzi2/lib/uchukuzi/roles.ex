defmodule Uchukuzi.Roles do
  @moduledoc """
  Module through users can be managed
  """

  use Uchukuzi.Roles.Model

  def login_manager(email, password) do
    person = get_by(Manager, email: email)

    cond do
      person && person.password_hash && Pbkdf2.verify_pass(password, person.password_hash) ->
        {:ok, person}

      person ->
        {:error, :unauthorized}

      true ->
        {:error, :not_found}
    end
  end

  def get_manager_by(params),
    do: get_by(Manager, params)

  def get_assistant_by(params),
    do: get_by(CrewMember, Keyword.put(params, :role, "assistant"))

  @spec get_by(any, any) :: any
  def get_by(module, params),
    do: Repo.get_by(module, params)
end
