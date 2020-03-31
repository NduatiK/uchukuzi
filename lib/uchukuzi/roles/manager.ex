defmodule Uchukuzi.Roles.Manager do
  use Uchukuzi.Roles.Model

  schema "managers" do
    field(:name, :string)
    field(:email, :string)
    field(:password, :string, virtual: true)
    field(:password_hash, :string)

    field(:auth_token, :string)
    field(:auth_token_expires_at, :utc_datetime_usec)

    belongs_to(:school, Uchukuzi.School.School)

    timestamps()
  end

  def new(name, email, password) do
    %Manager{}
    |> registration_changeset(%{name: name, email: email, password: password})
  end

  defp changeset(schema, params) do
    schema
    |> cast(params, __MODULE__.__schema__(:fields))
    |> cast(params, [:password])
    |> validate_required([:name, :email, :password])
    |> Validation.validate_email()
    |> unique_constraint(:email)
  end

  def registration_changeset(model, params) do
    model
    |> changeset(params)
    |> validate_length(:password, min: 6, max: 100)
    |> put_pass_hash()
    |> put_fresh_token()
  end

  def put_pass_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
        put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(pass))

      _ ->
        changeset
    end
  end

  defp auth_changeset(manager, attrs \\ %{}),
    do: cast(manager, attrs, [:auth_token, :auth_token_expires_at])

  def put_fresh_token(manager) do
    auth_token = Base.encode16(:crypto.strong_rand_bytes(24))
    expires_at = DateTime.add(DateTime.utc_now(), 14 * 24 * 3600, :second)
    auth_changeset(manager, %{auth_token: auth_token, auth_token_expires_at: expires_at})
  end
end
