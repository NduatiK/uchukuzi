defmodule Uchukuzi.Repo.Migrations.RemoveDefaultFuelDataFromBus do
  use Ecto.Migration

  def up do
    alter table(:buses) do
      remove(:stated_milage)
      remove(:fuel_type)
    end
  end

  def down do
    alter table(:buses) do
      add(:stated_milage, :float)
      add(:fuel_type, :string)
    end
  end
end
