defmodule Uchukuzi.Tracking.TripPath do
  alias __MODULE__
  alias Uchukuzi.Common.Location
  alias Uchukuzi.World.Tile
  alias Uchukuzi.World.ETA

  @moduledoc """
  Keeps track of the world and provides the following fuctionality:

  * Route Learning
  Learns the sequence of tiles followed by a bus on a given `Route`


  * ETA Prediction
  Given a stop along a route, predicts the time it will take to arrive
  """
  defstruct [
    # Tiles we predict on
    :anticipated_tile_locs,
    :deviation_radius,
    # Tiles crossed
    consumed_tile_locs: [],
    etas: [],
    needs_prediction_update: false,
    deviation_positions: []
  ]

  def new(nil, deviation_radius) do
    %TripPath{
      anticipated_tile_locs: nil,
      deviation_radius: deviation_radius
    }
  end

  def new(anticipated_tile_locs, deviation_radius) do
    %TripPath{
      anticipated_tile_locs: anticipated_tile_locs,
      deviation_radius: deviation_radius
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

  @spec set_needs_update(Uchukuzi.Tracking.TripPath.t()) :: Uchukuzi.Tracking.TripPath.t()
  def set_needs_update(%TripPath{} = path) do
    %{path | needs_prediction_update: true}
  end

  def update_predictions(path, nil), do: path
  def update_predictions(path, %{time: time}), do: update_predictions(%TripPath{} = path, time)

  def update_predictions(%TripPath{anticipated_tile_locs: nil} = path, _) do
    path
  end

  def update_predictions(%TripPath{needs_prediction_update: true} = path, date) do
    if date != nil do
      {_final_arrival_time, predictions} =
        path.anticipated_tile_locs
        |> ETA.predict_on_sequence_of_tiles(date)

      %{
        path
        | etas: predictions |> Enum.reverse(),
          needs_prediction_update: false
      }
    end
  end

  def update_predictions(%TripPath{} = path, _) do
    path
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
            |> Enum.take(4)
            |> Enum.find(fn x -> Tile.nearby?(x, tile, path.deviation_radius) end)

          case(match) do
            nil ->
              # If no match is found
              {:error, :major_deviation, tile}

            _ ->
              # Else anticipate the match and the cells after the match
              {:ok,
               path.anticipated_tile_locs
               |> Enum.drop_while(fn x -> x != match end)}
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

  def trim_etas(%TripPath{} = path, travel_time) do
    keep_first = fn list ->
      list
      |> Enum.uniq_by(fn {tile, _time} -> tile end)
    end

    keep_last = fn list ->
      list
      |> Enum.reverse()
      |> keep_first.()
      |> Enum.reverse()
    end

    etas = if travel_time == "evening" do
      path.etas
      |> keep_first.()
    else
      path.etas
      |> keep_last.()
    end

    %{path | etas: etas}
  end
end
