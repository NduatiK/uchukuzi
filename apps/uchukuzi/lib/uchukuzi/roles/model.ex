defmodule Uchukuzi.Roles.Model do
  @moduledoc false

  import Ecto.Changeset
  import Ecto.Query

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import Ecto.Query

      alias Uchukuzi.Repo

      alias Uchukuzi.Roles.Model

      alias Uchukuzi.Common.{
        Validation,
        Location
      }

      alias Uchukuzi.Roles.{
        Manager,
        Guardian,
        Student,
        Household,
        CrewMember
      }
    end
  end

  def downcase_email(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{email: _}} ->
        changeset
        |> update_change(:email, &String.downcase/1)

      _ ->
        changeset
    end
  end

  def put_pass_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
        put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(pass))

      _ ->
        changeset
    end
  end
end
