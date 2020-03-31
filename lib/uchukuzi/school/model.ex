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
        FuelRecord,
        ScheduledRepair,
        PerformedRepair
      }

      alias Uchukuzi.Roles.{
        Manager,
        Assistant
      }

      alias Uchukuzi.Common.{
        Geofence,
        Location
      }
    end
  end
end
