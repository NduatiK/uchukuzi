defmodule Uchukuzi.Roles do
  @moduledoc """
  Module through users can be managed
  """

  use Uchukuzi.Roles.Model

  def create_manager(_args) do
    Manager.new("name", "email", "password")
  end

  def create_student(_args) do
    Student.new("name", :evening)
  end

  def create_guardian(_args) do
    Guardian.new("name", "email", "password")
  end

  def create_assistant(_args) do
    Assistant.new("name", "email", "password")
  end

  # def login(args) do
  #   true
  # end

  def login_manager(email, password),
    do: login(Manager, email, password)

  def login(module, email, password) do
    person = get_by(module, email: email)

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

  @spec get_by(any, any) :: any
  def get_by(module, params),
    do: Repo.get_by(module, params)
end
