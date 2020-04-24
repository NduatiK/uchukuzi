defmodule Uchukuzi.School.Model do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      alias Uchukuzi.Repo
      use Ecto.Schema
      import Ecto.Changeset
      import Ecto.Query

      alias Uchukuzi.School.{
        Device,
        School,
        Route,
        Bus
      }

      alias Uchukuzi.School.Bus.{
        FuelReport,
        ScheduledRepair,
        PerformedRepair
      }

      alias Uchukuzi.Roles.{
        Manager,
        CrewMember
      }

      alias Uchukuzi.Common.{
        Geofence,
        Location,
        Validation
      }
    end
  end
end
