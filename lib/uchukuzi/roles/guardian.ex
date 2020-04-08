defmodule Uchukuzi.Roles.Guardian do
  @moduledoc """
  An individual who cares for a set of students typically a parent
  """
  use Uchukuzi.Roles.Model

  schema "guardians" do
    field(:name, :string)
    field(:email, :string)

    field(:password, :string, virtual: true)
    field(:password_hash, :string)

    has_many(:children, Student)

    timestamps()
  end

  def new(name, email, password) do
    %Guardian{}
    |> registration_changeset(%{name: name, email: email, password: password})
  end

  defp changeset(schema, params) do
    schema
    |> cast(params, __MODULE__.__schema__(:fields))
    |> validate_required([:name, :email, :password])
    |> Validation.validate_email()
    |> unique_constraint(:email)
  end
  def registration_changeset(model, params) do
    model
    |> changeset(params)
    |> validate_length(:password, min: 6, max: 100)
    |> put_pass_hash()
  end
end
