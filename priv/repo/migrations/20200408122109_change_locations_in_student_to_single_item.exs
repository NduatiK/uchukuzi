defmodule Uchukuzi.Repo.Migrations.ChangeLocationsInStudentToSingleItem do
  use Ecto.Migration

  def up do
    alter table("students") do
      remove(:pickup_location)
      remove(:home_location)
    end
    alter table("students") do
      add(:pickup_location, :jsonb, default: "{}")
      add(:home_location, :jsonb, default: "{}")
    end

  end

  def down do
    alter table("students") do
      remove(:pickup_location)
      remove(:home_location)
    end
    alter table("students") do
      add(:pickup_location, :jsonb, default: "[]")
      add(:home_location, :jsonb, default: "[]")
    end

  end
end
