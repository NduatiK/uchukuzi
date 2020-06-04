defmodule Uchukuzi.Repo.Migrations.AddDeviationRadiusToSchool do
  use Ecto.Migration

  def up do
    alter(table(:schools)) do
      add(:deviation_radius, :integer, default: 1)
    end
  end

  def down do
    alter(table(:schools)) do
      remove(:deviation_radius)
    end
  end
end
