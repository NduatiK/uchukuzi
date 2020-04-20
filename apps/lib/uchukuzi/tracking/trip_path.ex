defmodule Uchukuzi.Tracking.TripPath do
  alias __MODULE__
  alias Uchukuzi.Common.Location
  alias Uchukuzi.World.Tile
  alias Uchukuzi.World.ETA

  defstruct [
    # Tiles crossed
    :consumed_tiles,
    # Tiles we predict on
    :anticipated_tiles,
    eta: %{},
    needs_prediction_update: true
  ]

  def new(anticipated_tiles) do
    %TripPath{
      anticipated_tiles: Enum.reverse(anticipated_tiles),
      consumed_tiles: []
    }
  end

  def crossed_tiles(%TripPath{} = path, tiles) do
    case {path.consumed_tiles, tiles} do
      #  If the tiles overlap, ignore the first new tile
      {[h | _], [h | []]} ->
        path

      #  If the tiles overlap, ignore the first new tile
      {[h | _], [h | tail]} ->
        tail
        |> Enum.reduce(path, fn t, path ->
          entered_tile(path, t)
        end)
        |> set_needs_update()

      #  Otherwise just add it
      _ ->
        tiles
        |> Enum.reduce(path, fn t, path ->
          entered_tile(path, t)
        end)
        |> set_needs_update()
    end
  end

  def set_needs_update(%TripPath{} = path) do
    %{path | needs_prediction_update: true}
  end

  def update_predictions(%TripPath{needs_prediction_update: false} = path) do
    path
  end

  def update_predictions(%TripPath{} = path, date \\ DateTime.utc_now()) do
    {_, predictions} = ETA.predict_on_sequence_of_tiles(path.anticipated_tiles, date)

    %{
      path
      | eta: predictions,
        needs_prediction_update: false
    }
  end

  def entered_tile(%TripPath{} = path, %Tile{} = tile) do
    anticipated = calculate_anticipated_tiles(path, tile)

    path
    |> prepend_tile(tile)
    |> apply_anticipated_tiles(anticipated)
  end

  def prepend_tile(%TripPath{} = path, %Tile{} = tile),
    do: %{
      path
      | consumed_tiles: [tile | path.consumed_tiles]
    }

  def calculate_anticipated_tiles(%TripPath{} = path, %Tile{} = tile) do
    with [h | tail] <- path.anticipated_tiles do
      cond do
        # A match
        tile == h ->
          {:ok, tail}

        # A skip -> look for a match near the head of the list
        tile in Enum.take(path.anticipated_tiles, 9) ->
          {:ok,
           path.anticipated_tiles
           |> Enum.drop_while(fn x -> x != tile end)
           |> Enum.drop(1)}

        # A deviation - attempt recovery
        true ->
          # Look for a nearby anticipated cell
          match =
            path.anticipated_tiles
            |> Enum.take(9)
            |> Enum.find(fn x -> Tile.nearby?(x, tile) end)

          case(match) do
            nil ->
              # If no match is found
              {:error, :major_deviation, tile}

            _ ->
              # Else anticipate the cells after the match
              {:ok,
               path.anticipated_tiles
               |> Enum.drop_while(fn x -> x != match end)
               |> Enum.drop(1)}
          end
      end
    else
      [] ->
        {:error, :no_anticipated_tiles_left}
    end
  end

  def apply_anticipated_tiles(%TripPath{} = path, {:ok, anticipated_tiles}) do
    %{path | anticipated_tiles: anticipated_tiles}
  end

  def apply_anticipated_tiles(%TripPath{} = path, {:error, :no_anticipated_tiles_left}) do
    %{path | anticipated_tiles: []}
  end

  def apply_anticipated_tiles(%TripPath{} = path, {:error, :major_deviation, _tile}) do
    path
    # %{path | deviated: true}
  end
end
