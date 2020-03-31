defmodule Uchukuzi.Roles.Model do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import Ecto.Query

      alias Uchukuzi.Repo

      alias Uchukuzi.Common.Validation

      alias Uchukuzi.Roles.{
        Manager,
        Guardian,
        Student,
        Household,
        Assistant
      }
    end
  end
end
