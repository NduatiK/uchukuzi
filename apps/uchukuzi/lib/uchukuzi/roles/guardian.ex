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

  def new(name, email) do
    %Guardian{}
    |> changeset(%{name: name, email: email})
  end

  def changeset(schema, params) do
    schema
    |> cast(params, __MODULE__.__schema__(:fields))
    |> validate_required([:name, :email])
    |> Validation.validate_email()
    |> unique_constraint(:email)
  end
end
