defmodule Uchukuzi.Repo.Migrations.AddBusAndDevice do
  use Ecto.Migration

  def up do
    create table("buses") do
      add(:name, :string)

      add(:number_plate, :string)
      add(:seats_available, :integer)
      add(:vehicle_type, :string)

      # Km / L
      add(:stated_milage, :float)
      add(:fuel_type, :string)

      add(:school_id, references("schools"))

      timestamps()
    end

    create(unique_index("buses", ["school_id", "number_plate"]))

    ########### DEVICES ###########

    create table("devices") do
      add(:imei, :string)

      add(:bus_id, references("buses"))
      add(:school_id, references("schools"))

      timestamps()
    end

    create(unique_index("devices", ["imei"]))

    ########### FUEL REPORTS ###########

    create table("crew_members") do
      add(:name, :string)

      add(:role, :string)
      add(:email, :string)
      add(:phone_number, :string)

      add(:school_id, references("schools"))
      add(:bus_id, references("buses"))

      timestamps()
    end

    create(unique_index("crew_members", [:email]))
  end

  def down do
    drop(table(:crew_members))
    drop(table(:devices))
    drop(table(:buses))
  end
end
