defmodule Uchukuzi.Roles.Model do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import Ecto.Query

      alias Uchukuzi.Repo

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

      def put_pass_hash(changeset) do
        case changeset do
          %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
            put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(pass))

          _ ->
            changeset
        end
      end
    end
  end
end
