defmodule Uchukuzi.Repo.Migrations.AddTripsMadeToFuelRecords do
  use Ecto.Migration
  def up do
    alter(table(:fuel_records)) do
      add(:trips_made, :integer)
    end
  end

  def down do
    alter(table(:fuel_records)) do
      remove(:trips_made)
    end
  end
end
