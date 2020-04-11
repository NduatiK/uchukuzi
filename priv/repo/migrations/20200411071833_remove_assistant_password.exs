defmodule Uchukuzi.Repo.Migrations.RemoveAssistantPassword do
  use Ecto.Migration

  def up do
    alter(table(:assistants)) do
      remove(:password_hash)
    end
  end

  def down do
    alter(table(:assistants)) do
      add(:password_hash, :string)
    end
  end
end
