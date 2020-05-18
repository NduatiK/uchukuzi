defmodule Uchukuzi.Repo.Migrations.RemoveUnneededFields do
  use Ecto.Migration

  def up do
    alter(table(:trips)) do
      remove(:crossed_tiles_hash)
    end

    alter(table(:students)) do
      remove(:pickup_location)
    end
  end

  def down do
    alter(table(:trips)) do
      add(:crossed_tiles_hash, :string)
    end

    alter(table(:students)) do
      add(:pickup_location, :jsonb, default: "{}")
    end
  end
end
