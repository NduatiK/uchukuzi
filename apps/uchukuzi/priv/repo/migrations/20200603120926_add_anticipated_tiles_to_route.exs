defmodule Uchukuzi.Repo.Migrations.AddAnticipatedTilesToRoute do
  use Ecto.Migration

  def up do
    alter(table(:trip_reports)) do
      add(:crossed_tiles, :jsonb, default: "[]")
    end

    alter(table(:routes)) do
      add(:expected_tiles, :jsonb, default: "[]")
    end

    alter(table(:trips)) do
      remove(:crossed_tiles)
    end
  end

  def down do
    alter(table(:trips)) do
      add(:crossed_tiles, :jsonb, default: "[]")
    end

    alter(table(:routes)) do
      remove(:expected_tiles)
    end

    alter(table(:trip_reports)) do
      remove(:crossed_tiles)
    end
  end
end
