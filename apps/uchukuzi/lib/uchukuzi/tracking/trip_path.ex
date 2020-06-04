defmodule Uchukuzi.Tracking.TripPath do
  alias __MODULE__
  alias Uchukuzi.Common.Location
  alias Uchukuzi.World.Tile
  alias Uchukuzi.World.ETA

  defstruct [
    # Tiles we predict on
    :anticipated_tile_locs,
    # Tiles crossed
    consumed_tile_locs: [],
    eta: %{},
    needs_prediction_update: false,
    deviation_positions: []
  ]

  def new(nil) do
    %TripPath{
      anticipated_tile_locs: nil
    }
  end

  def new(anticipated_tile_locs) do
    %TripPath{
      anticipated_tile_locs:
        anticipated_tile_locs
        |> Enum.reverse()
    }
  end

  def crossed_tiles(%TripPath{} = path, tile_locs) do
    case {path.consumed_tile_locs, tile_locs} do
      #  If the tiles overlap, ignore the first new tile
      {[h | _], [h | tail]} ->
        tail
        |> Enum.reduce(path, fn t, path ->
          entered_tile(path, t)
        end)

      #  Otherwise just add it
      _ ->
        tile_locs
        |> Enum.reduce(path, fn t, path ->
          entered_tile(path, t)
        end)
    end
    |> set_needs_update()
  end

  def set_needs_update(%TripPath{} = path) do
    %{path | needs_prediction_update: true}
  end

  def update_predictions(path, nil), do: path
  def update_predictions(path, %{time: time}), do: update_predictions(%TripPath{} = path, time)

  def update_predictions(%TripPath{anticipated_tile_locs: nil} = path, _) do
    path
  end

  def update_predictions(%TripPath{needs_prediction_update: false} = path, _) do
    path
  end

  def update_predictions(%TripPath{} = path, date) do
    if date != nil do
      {_final_arrival_time, predictions} =
        ETA.predict_on_sequence_of_tiles(path.anticipated_tile_locs, date)

      %{
        path
        | eta: predictions,
          needs_prediction_update: false
      }
    end
  end

  def entered_tile(%TripPath{anticipated_tile_locs: nil} = path, %Location{} = tile) do
    path
    |> prepend_tile(tile)
  end

  def entered_tile(%TripPath{} = path, %Location{} = tile) do
    anticipated = calculate_anticipated_tile_locs(path, tile)

    path
    |> prepend_tile(tile)
    |> apply_anticipated_tile_locs(anticipated)
  end

  def prepend_tile(%TripPath{} = path, %Location{} = tile),
    do: %{
      path
      | consumed_tile_locs: [tile | path.consumed_tile_locs]
    }

  def calculate_anticipated_tile_locs(%TripPath{} = path, %Location{} = tile) do
    with [h | tail] <- path.anticipated_tile_locs do
      cond do
        # A match
        tile == h ->
          {:ok, tail}

        # A skip -> look for a match near the head of the list
        tile in Enum.take(path.anticipated_tile_locs, 9) ->
          {:ok,
           path.anticipated_tile_locs
           |> Enum.drop_while(fn x -> x != tile end)
           |> Enum.drop(1)}

        # A deviation - attempt recovery
        true ->
          # Look for a nearby anticipated cell
          match =
            path.anticipated_tile_locs
            |> Enum.take(9)
            |> Enum.find(fn x -> Tile.nearby?(x, tile) end)

          case(match) do
            nil ->
              # If no match is found
              {:error, :major_deviation, tile}

            _ ->
              # Else anticipate the match and the cells after the match
              {:ok,
               path.anticipated_tile_locs
               |> Enum.drop_while(fn x -> x != match end)
              }
          end
      end
    else
      [] ->
        {:error, :no_anticipated_tile_locs_left}
    end
  end

  def apply_anticipated_tile_locs(%TripPath{} = path, {:ok, anticipated_tile_locs}) do
    %{path | anticipated_tile_locs: anticipated_tile_locs}
  end

  def apply_anticipated_tile_locs(%TripPath{} = path, {:error, :no_anticipated_tile_locs_left}) do
    %{path | anticipated_tile_locs: []}
  end

  def apply_anticipated_tile_locs(%TripPath{} = path, {:error, :major_deviation, _tile}) do
    %{
      path
      | deviation_positions: [Enum.count(path.consumed_tile_locs) - 1 | path.deviation_positions]
    }
  end
end
