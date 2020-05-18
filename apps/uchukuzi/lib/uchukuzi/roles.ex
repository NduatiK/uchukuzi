defmodule Uchukuzi.Roles do
  @moduledoc """
  Module through users can be managed
  """

  use Uchukuzi.Roles.Model

  def login_manager(email, password) do
    manager = get_by(Manager, email: email)

    cond do
      manager && manager.password_hash && Pbkdf2.verify_pass(password, manager.password_hash) ->
        {:ok, manager}

      manager ->
        {:error, :unauthorized}

      true ->
        {:error, :not_found}
    end
  end

  def set_manager_email_verified(manager) do
    manager
    |> change(email_verified: true)
    |> Repo.update()
  end

  def get_manager_by(params),
    do: get_by(Manager, params)

  def get_assistant_by(params),
    do: get_by(CrewMember, Keyword.put(params, :role, "assistant"))

  def get_student_by(params),
    do: get_by(Student, params)

  def get_guardian_by(params),
    do: get_by(Guardian, params)

  @spec get_by(any, any) :: any
  def get_by(module, params),
    do: Repo.get_by(module, params)


  def update_student_email(%Student{} = student, email) do
    student
    |> change(email: email)
    |> Repo.update()
  end

end
