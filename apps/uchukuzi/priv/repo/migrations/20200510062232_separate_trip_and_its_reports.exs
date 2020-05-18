defmodule Uchukuzi.Repo.Migrations.SeparateTripAndItsReports do
  use Ecto.Migration

  def up do
    alter(table(:trips)) do
      remove(:reports)
    end

    create(table(:trip_reports)) do
      add(:trip_id, references(:trips), on_delete: :delete_all)
      add(:reports, :jsonb, default: "[]")
    end
  end

  def down do
    drop(table(:trip_reports))

    alter(table(:trips)) do
      add(:reports, :jsonb, default: "[]")
    end
  end
end
