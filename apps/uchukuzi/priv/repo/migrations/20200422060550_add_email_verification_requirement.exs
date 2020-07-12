defmodule Uchukuzi.Repo.Migrations.AddEmailVerificationRequirement do
  use Ecto.Migration

  def up do
    alter table("managers") do
      add(:email_verified, :boolean, default: false)
    end
  end

  def down do
    alter table("managers") do
      remove(:email_verified)
    end
  end
end
