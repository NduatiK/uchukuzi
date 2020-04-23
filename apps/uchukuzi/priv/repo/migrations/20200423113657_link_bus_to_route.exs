defmodule Uchukuzi.Repo.Migrations.LinkBusToRoute do
  use Ecto.Migration

  def up do
    alter (table "buses") do
      add(:route_id, references("routes"))
    end
  end

  def down do
    alter (table "buses") do
      remove(:route_id)
    end
  end

end
