defmodule Uchukuzi.Repo.Migrations.AddSchoolAndRoles do
  use Ecto.Migration

  def up do
    create table("schools") do
      add(:name, :string)
      add(:perimeter, :jsonb, default: "[]")
    end

    # *########## MANAGER ###########

    create table("managers") do
      add(:name, :string)
      add(:email, :string)
      add(:password_hash, :string)

      add(:school_id, references("schools"))

      timestamps()
    end

    create(unique_index("managers", [:email]))

    # *########## GUARDIANS ###########

    create table("guardians") do
      add(:name, :string)

      add(:email, :string)
      add(:phone_number, :string)

      add(:school_id, references("schools"))

      timestamps()
    end

    create(unique_index("guardians", [:email]))

    # *########## STUDENT ###########

    create table("students") do
      add(:name, :string)

      add(:travel_time, :string)
      add(:pickup_location, :jsonb, default: "{}")
      add(:home_location, :jsonb, default: "{}")

      add(:email, :string)

      add(:school_id, references("schools"))
      add(:guardian_id, references("guardians"))

      timestamps()
    end

    create(unique_index("students", [:email, :school_id]))
  end

  def down do
    drop(table(:students))
    drop(table(:guardians))
    drop(table(:managers))
    drop(table(:schools))
  end
end
