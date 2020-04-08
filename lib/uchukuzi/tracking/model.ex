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
      # alias Uchukuzi.Tracking.{

      # }

      # alias Uchukuzi.School.Bus.{
      #   FuelRecord,
      #   ScheduledRepair,
      #   PerformedRepair
      # }

      # alias Uchukuzi.Roles.{
      #   Manager,
      #   Assistant
      # }

      alias Uchukuzi.Common.{
        Geofence,
        Location,
        Report,
        Validation
      }
    end
  end
end
