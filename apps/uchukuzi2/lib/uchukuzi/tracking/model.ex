defmodule Uchukuzi.Tracking.Model do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      alias Uchukuzi.Repo
      use Ecto.Schema
      import Ecto.Changeset
      import Ecto.Query

      alias Uchukuzi.School
      alias Uchukuzi.Tracking


      alias Uchukuzi.Common.{
        Geofence,
        Location,
        Report,
        Validation
      }
    end
  end
end
