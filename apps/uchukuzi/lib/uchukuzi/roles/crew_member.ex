defmodule Uchukuzi.Roles.CrewMember do
  @moduledoc """
  An employee of a school assigned to a bus who records the
  boarding and exiting of students from a bus
  """
  use Uchukuzi.Roles.Model

  @roles ["assistant", "driver"]

  schema "crew_members" do
    field(:name, :string)
    field(:email, :string)
    field(:phone_number, :string)
    field(:role, :string)

    belongs_to(:school, Uchukuzi.School.School)
    belongs_to(:bus, Uchukuzi.School.Bus)

    timestamps()
  end

  def changeset(schema \\ %__MODULE__{}, params) do
    schema
    |> cast(params, __MODULE__.__schema__(:fields))
    |> validate_required([:name, :email, :phone_number, :role])
    |> validate_inclusion(:role, @roles)
    |> Model.downcase_email()
    |> Validation.validate_email()
    |> Validation.validate_phone_number()
    |> unique_constraint(:email)
  end
end
