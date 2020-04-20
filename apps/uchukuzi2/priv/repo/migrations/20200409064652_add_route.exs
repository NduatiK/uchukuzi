defmodule Uchukuzi.Repo.Migrations.AddRoute do
  use Ecto.Migration

  def up do
    create(table(:routes)) do
      add(:school_id, references(:schools))
      add(:name, :string)
      add(:path, :jsonb, default: "[]")
    end
  end

  def down do
    drop(table(:routes))
  end
end
