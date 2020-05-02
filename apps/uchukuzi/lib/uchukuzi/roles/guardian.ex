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
    changeset =
      schema
      |> cast(params, __MODULE__.__schema__(:fields))
      |> validate_required([:name, :email])
      |> update_change(:email, &String.downcase/1)
      |> Validation.validate_email()

    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{email: _}} ->
        changeset
        |> unique_constraint(:email)

      _ ->
        changeset
    end
  end
end
