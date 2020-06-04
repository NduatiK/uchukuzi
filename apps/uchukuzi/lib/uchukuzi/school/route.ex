defmodule Uchukuzi.School.Route do
  @moduledoc """
  The school defined path that a bus is expected to
  follow in order to pick and drop students
  """
  alias __MODULE__

  use Uchukuzi.School.Model

  schema "routes" do
    field(:name, :string)

    embeds_many(:path, Location, on_replace: :delete)

    embeds_many(:expected_tiles, Location, on_replace: :delete)

    belongs_to(:school, School)
    has_one(:bus, Bus)

    has_many(:students, Uchukuzi.Roles.Student)
  end

  def changeset(schema \\ %__MODULE__{}, params) do
    schema
    |> cast(params, [:name, :school_id])
    |> validate_required([:name, :school_id])
    |> cast_embed(:path, with: &Location.changeset/2)
    |> cast_embed(:expected_tiles, with: &Location.changeset/2)
  end

  def calculate_expected_tiles(%Route{} = route) do
    route.path
    |> Enum.reduce([], fn location, tiles ->
      new_tile = Uchukuzi.World.Tile.name(location)

      case tiles do
        [] -> [new_tile]
        [h | _] when h != new_tile -> [new_tile | tiles]
        _ -> tiles
      end

      tiles
    end)
    |> Enum.reverse()
    |> (fn tiles -> %{route | expected_tiles: tiles} end).()
  end
end
