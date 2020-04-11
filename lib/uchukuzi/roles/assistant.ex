defmodule Uchukuzi.Roles.Assistant do
  @moduledoc """
  An employee of a school assigned to a bus who records the
  boarding and exiting of students from a bus
  """
  use Uchukuzi.Roles.Model

  schema "assistants" do
    field(:name, :string)
    field(:email, :string)
    field(:phone_number, :string)

    belongs_to(:school, Uchukuzi.School.School)
    belongs_to(:bus, Uchukuzi.School.Bus)

    timestamps()
  end

  def new(name, email, phone_number) do
    %Assistant{}
    |> changeset(%{
      name: name,
      email: email,
      phone_number: phone_number
    })
  end

  defp changeset(schema, params) do
    schema
    |> cast(params, __MODULE__.__schema__(:fields))
    |> validate_required([:name, :email])
    |> Validation.validate_email()
    |> Validation.validate_phone_number()
    |> unique_constraint(:email)
  end
end
