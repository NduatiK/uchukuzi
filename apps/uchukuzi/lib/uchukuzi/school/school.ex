defmodule Uchukuzi.School.School do
  use Uchukuzi.School.Model

  alias __MODULE__

  schema "schools" do
    field(:name, :string)

    embeds_one(:perimeter, Geofence, on_replace: :delete)

    has_one(:manager, Uchukuzi.Roles.Manager)
    has_many(:buses, Bus)
    has_many(:routes, Route)

    field(:deviation_radius, :integer, default: 2)
  end

  def new(name, perimeter) do
    %School{}
    |> changeset(%{name: name, perimeter: perimeter})
  end

  @spec changeset(
          {map, map} | %{:__struct__ => atom | %{__changeset__: map}, optional(atom) => any},
          :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}
        ) :: map
  def changeset(schema \\ %__MODULE__{}, params) do
    schema
    |> cast(params, [:name])
    |> validate_required([:name])
    |> cast_embed(:perimeter, with: &Geofence.school_changeset/2)
  end

  @spec contains_point?(Uchukuzi.School.School.t(), Uchukuzi.Common.Location.t()) :: boolean
  def contains_point?(%School{} = school, %Location{} = location) do
    Geofence.contains_point?(school.perimeter, location)
  end
end
