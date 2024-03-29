defmodule Uchukuzi.Roles.Manager do
  use Uchukuzi.Roles.Model

  schema "managers" do
    field(:name, :string)
    field(:email, :string)

    field(:email_verified, :boolean, default: false)

    field(:password, :string, virtual: true)
    field(:password_hash, :string)

    belongs_to(:school, Uchukuzi.School.School)

    timestamps()
  end

  # def new(name, email, password) do
  #   %Manager{}
  #   |> registration_changeset(%{name: name, email: email, password: password})
  # end

  def changeset(schema, params) do
    schema
    |> cast(params, [:password | __MODULE__.__schema__(:fields)])
    |> validate_required([:name, :email, :password])
    |> Model.downcase_email()
    |> Validation.validate_email()
    |> unique_constraint(:email)
  end

  def registration_changeset(model, params) do
    model
    |> changeset(params)
    |> validate_length(:password, min: 6, max: 100)
    |> Model.put_pass_hash()
  end
end
