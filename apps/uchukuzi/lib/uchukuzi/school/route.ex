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
    |> calculate_expected_tiles()
  end

  def calculate_expected_tiles(%Ecto.Changeset{valid?: false} = changeset) do
    changeset
  end

  def calculate_expected_tiles(%Ecto.Changeset{changes: %{path: path}} = changeset) do
    expected_tiles =
      path
      |> Enum.map(& &1.data)
      |> Enum.filter(&(&1 != %Uchukuzi.Common.Location{lat: nil, lng: nil}))
      |> calculate_expected_tiles()
      |> Enum.map(& &1.coordinate)

    put_change(changeset, :expected_tiles, expected_tiles)
  end

  def calculate_expected_tiles(path) do
    path
    |> Enum.reduce({nil, []}, fn location, {last_location, tiles} ->
      if last_location == nil do
        {location, [Uchukuzi.World.Tile.new(location)]}
      else
        new_tile = Uchukuzi.World.Tile.new(location)

        # Between tiles other than start and end_tiles
        # Order from location to last location
        crossed =
          Uchukuzi.World.crossed_tiles(last_location, location)
          |> Enum.reverse()

        # tiles is now
        # the current_tile
        # ++ the tiles crossed between the current and previous tile
        # ++ all tiles from the previous tile to the first tile
        {location, [new_tile | crossed] ++ tiles}
      end
    end)
    |> (fn {_, tiles} -> tiles end).()
    |> Enum.reverse()
  end
end
