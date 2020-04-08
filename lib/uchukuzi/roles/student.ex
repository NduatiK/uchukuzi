defmodule Uchukuzi.Roles.Student do
  @travel_times ~w(morning evening two_way)
  @moduledoc """
  An school bus user who attends a specific school.

  A student may be registered to use the bus in the
  morning and/or evening (#{
    Enum.reduce(@travel_times, &(&2 <> ", " <> &1)) |> String.replace_suffix(",", "")
  })

  A student may be granted access to bus details by their `Guardian` through their email
  """
  use Uchukuzi.Roles.Model

  schema "students" do
    field(:name, :string)
    field(:email, :string)

    field(:password, :string, virtual: true)
    field(:password_hash, :string)

    field(:travel_time, :string)

    belongs_to(:school, Uchukuzi.School.School)

    timestamps()
  end

  def new(school, name, travel_time, email \\ nil),
    do: changeset(%{name: name, travel_time: travel_time, email: email, school_id: school})

  defp changeset(schema \\ %Student{}, params) do
    schema
    |> cast(params, __MODULE__.__schema__(:fields))
    |> validate_required([:name, :travel_time])
    |> Validation.validate_email()
    |> unique_constraint(:email)
  end

  def is_student(%Student{}), do: true
  def is_student(_), do: false
end
