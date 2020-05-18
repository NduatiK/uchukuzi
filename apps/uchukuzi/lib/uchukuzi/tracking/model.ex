defmodule Uchukuzi.Tracking.Model do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      alias Uchukuzi.School
      alias Uchukuzi.School.Bus

      alias Uchukuzi.World.Tile

      alias Uchukuzi.Tracking

      alias Uchukuzi.Tracking.{
        Trip,
        TripPath,
        StudentActivity,
        TripTracker,
        BusServer,
        BusesSupervisor
      }

      alias Uchukuzi.Tracking.Trip.ReportCollection

      alias Uchukuzi.Common.{
        Geofence,
        Location,
        Report,
        Validation
      }

      alias Uchukuzi.Repo
      use Ecto.Schema
      import Ecto.Changeset
      import Ecto.Query
    end
  end
end
