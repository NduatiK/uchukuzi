defmodule Uchukuzi.Roles.Driver do
  @moduledoc """
  An bus driver
  """
  use Uchukuzi.Roles.Model

  schema "drivers" do
    field(:name, :string)
    field(:email, :string)
    field(:phone_number, :string)

    belongs_to(:school, Uchukuzi.School.School)
    belongs_to(:bus, Uchukuzi.School.Bus)

    timestamps()
  end

  def new(name, email, phone_number) do
    %Driver{}
    |> changeset(%{
      name: name,
      email: email,
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
end
