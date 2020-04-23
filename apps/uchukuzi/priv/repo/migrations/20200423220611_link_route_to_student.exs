defmodule Uchukuzi.Repo.Migrations.LinkRouteToStudent do
  use Ecto.Migration

  def up do
    alter table("students") do
      add(:route_id, references("routes"))
    end
  end

  def down do
    alter table("students") do
      remove(:route_id)
    end
  end
end
