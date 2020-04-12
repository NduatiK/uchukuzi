defmodule Uchukuzi.Repo.Migrations.AddRoleToCrewMember do
  use Ecto.Migration

  def up do
    alter(table(:crew_members)) do
      add(:role, :string)
    end
  end

  def down do
    alter(table(:crew_members)) do
      remove(:role)
    end
  end
end
