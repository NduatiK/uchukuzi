defmodule Uchukuzi.Roles.Guardian do
  @moduledoc """
  An individual who cares for a set of students typically a parent
  """
  use Uchukuzi.Roles.Model


  schema "guardians" do
    field(:name, :string)
    field(:email, :string)
    field(:phone_number, :string)

    has_many(:students, Student)

    timestamps()
  end

  def changeset(schema, params) do
    changeset =
      schema
      |> cast(params, __MODULE__.__schema__(:fields))
      |> validate_required([:name, :email])
      |> Model.downcase_email()
      |> Validation.validate_email()
      |> unique_constraint(:email)
  end
end
