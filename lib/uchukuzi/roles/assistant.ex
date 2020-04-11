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

    timestamps()
  end

  def new(name, email, phone_number, password) do
    %Assistant{}
    |> registration_changeset(%{
      name: name,
      email: email,
      password: password,
      phone_number: phone_number
    })
  end

  defp changeset(schema, params) do
    schema
    |> cast(params, __MODULE__.__schema__(:fields))
    |> validate_required([:name, :email, :password])
    |> Validation.validate_email()
    |> Validation.validate_phone_number()
    |> unique_constraint(:email)
  end

  def registration_changeset(model, params) do
    model
    |> changeset(params)
    |> validate_length(:password, min: 6, max: 100)
  end
end
