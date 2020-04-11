defmodule Uchukuzi.Repo.Migrations.AddDriverAndAddBusToAssistant do
  use Ecto.Migration

  def up do
    create table("drivers") do
      add(:name, :string)

      add(:email, :string)
      add(:phone_number, :string)

      add(:school_id, references("schools"))
      add(:bus_id, references("buses"))

      timestamps()
    end

    alter table(:assistants) do
      add(:bus_id, references("buses"))
    end
  end

  def down do
    alter table(:assistants) do
      remove(:bus_id)
    end

    drop(table("drivers"))
  end
end
