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

    field(:travel_time, :string)

    embeds_one(:pickup_location, Location, on_replace: :delete)
    embeds_one(:home_location, Location, on_replace: :delete)

    belongs_to(:school, Uchukuzi.School.School)
    belongs_to(:guardian, Guardian)
    belongs_to(:route, Uchukuzi.School.Route)

    timestamps()
  end

  # def new(school, name, travel_time, email \\ nil),
  #   do: changeset(%{name: name, travel_time: travel_time, email: email, school_id: school})

  def changeset(schema \\ %Student{}, params, pickup_location, home_location, school_id, route_id) do
    params =
      params
      |> Map.put("pickup_location", pickup_location)
      |> Map.put("home_location", home_location)
      |> Map.put("school_id", school_id)
      |> Map.put("route_id", route_id)

    changeset(schema, params)
  end

  def changeset(schema \\ %Student{}, params) do
    schema
    |> cast(params, [:name, :email, :school_id, :route_id, :guardian_id, :travel_time])
    |> validate_required([:name, :travel_time])
    |> cast_embed(:pickup_location, with: &Location.changeset/2)
    |> cast_embed(:home_location, with: &Location.changeset/2)
    |> Validation.validate_email()
    |> unique_constraint(:email)
  end

  def is_student(%Student{}), do: true
  def is_student(_), do: false
end
