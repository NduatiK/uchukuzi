defmodule Uchukuzi.Repo.Migrations.AddDeviationPositionsToReportCollection do
  use Ecto.Migration

  def up do
    alter(table(:trip_reports)) do
      add(:deviation_positions, {:array, :integer}, default: [])
    end
  end

  def down do
    alter(table(:trip_reports)) do
      remove(:deviation_positions)
    end
  end
end
