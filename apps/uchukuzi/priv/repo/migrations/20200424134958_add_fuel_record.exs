defmodule Uchukuzi.Repo.Migrations.AddFuelRecord do
  use Ecto.Migration

  def up do
    create(table(:fuel_records)) do
      add(:bus_id, references(:buses))

      add(:volume, :float)
      add(:cost, :integer)
      add(:date, :naive_datetime)

    end
  end

  def down do
    drop(table(:fuel_records))
  end
end
