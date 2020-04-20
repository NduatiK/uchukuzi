defmodule Uchukuzi.Repo.Migrations.AddTrips do
  use Ecto.Migration

  def up do
    create(table(:trips)) do
      add(:bus_id, references(:buses))

      add(:start_time, :utc_datetime_usec)
      add(:end_time, :utc_datetime_usec)

      add(:reports, :jsonb, default: "[]")
      add(:crossed_tiles, :jsonb, default: "[]")
      add(:student_activities, :jsonb, default: "[]")

      add(:distance_covered, :float)
      add(:travel_time, :string)
      add(:crossed_tiles_hash, :string)

    end
  end

  def down do
    drop(table(:trips))
  end
end
