defmodule Uchukuzi.Repo.Migrations.AddPerformedRepair do
  use Ecto.Migration

  def up do
    create(table(:performed_repairs)) do
      add(:bus_id, references(:buses))

      add(:cost, :float)
      add(:part, :string)
      add(:description, :string, size: 510)

      timestamps()
    end
  end

  def down do
    drop(table(:performed_repairs))
  end
end
