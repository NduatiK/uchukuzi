defmodule Uchukuzi.World.ETA do
  alias Uchukuzi.World.ETA.LearnerWorker
  alias Uchukuzi.World.ETA.PredictionWorker
  alias Uchukuzi.DiskDB
  alias Uchukuzi.Common.Location
  alias Uchukuzi.World.Tile

  def start_up() do
    Uchukuzi.DiskDB.createTable(__MODULE__)
  end

  def dateToHourValue(date),
    do: date.hour + date.minute / 60

  def insert(_, _, cross_time) when cross_time > 1200 do
  end

  def insert(tile, %DateTime{} = date, cross_time) do
    insert(tile, dateToHourValue(date), cross_time)
  end

  def insert(tile, time_value, cross_time) do
    with {:ok, dataset} <- DiskDB.get(tile.coordinate, __MODULE__) do
      [[time_value, cross_time] | dataset]
      |> Enum.take(1000)
      |> DiskDB.insert(__MODULE__, tile.coordinate)
    else
      {:error, _} ->
        [[time_value, cross_time]]
        |> DiskDB.insert(__MODULE__, tile.coordinate)
    end
  end

  def rebuild_models() do
    Uchukuzi.DiskDB.get_all(Uchukuzi.World.ETA)
    |> Enum.map(&learn_on_tile/1)
    |> (fn x ->
          IO.inspect(label: "Trained #{Enum.count(x)}")
          x
        end).()
  end

  def learn_on_tile({k, v}) do
    LearnerWorker.learn(k, v)
  end

  def coordinate_hash(%Tile{} = tile) do
    coordinate_hash(tile.coordinate)
  end

  def coordinate_hash(%Location{} = coordinate) do
    :crypto.hash(:sha, "#{coordinate.lat}_#{coordinate.lng}")
    |> Base.encode32()
  end

  def predict_cross_time(%Tile{} = tile, current_time),
    do: predict_cross_time(tile.coordinate, current_time)

  def predict_cross_time(%Location{} = coordinate, %DateTime{} = date) do
    predict_cross_time(coordinate, dateToHourValue(date))
  end

  def predict_cross_time(%Location{} = coordinate, hour_value) when is_number(hour_value) do
    PredictionWorker.predict(coordinate, hour_value)
  end

  def predict_on_sequence_of_tiles(sequence, %DateTime{} = date) do
    predict_on_sequence_of_tiles(sequence, dateToHourValue(date))
  end

  def predict_on_sequence_of_tiles(sequence, hour_value) when is_number(hour_value) do
    # for tile <- Enum.reverse() do
    sequence
    |> Enum.with_index()
    |> Enum.reduce({hour_value, []}, fn {tile, index}, {hour_value, acc} ->
      [prediction_in_seconds] = predict_cross_time(tile, hour_value)

      hour_value =
        (hour_value + prediction_in_seconds / 3600)
        |> cleanse_hour_value()

      # IO.inspect(coordinate_hash(tile), label: "name")

      error_compensated_hour_value =
        hour_value
        |> adjust_by_index(index)
        |> cleanse_hour_value()

      {hour_value, [{tile, error_compensated_hour_value} | acc]}
    end)
  end

  def cleanse_hour_value(hour_value) do
    cond do
      hour_value >= 24 ->
        hour_value - 24

      hour_value < 0 ->
        hour_value + 24

      true ->
        hour_value
    end
  end

  def adjust_by_index(hour_value, x) do
    # a = 0.5805
    # b = -0.0467

    # a = 1.1918
    # b = 0.4747

    a = 1.4066
    b = -0.5105

    y = a * x + b
    # y = (a * x * x / 4 + a * x + b) / 60
    a0 = 0.1166
    a1 = 1.5381
    a2 = -0.0066
    a3 = 5.8506e-5
    y = a0 + a1 * x + a2 * :math.pow(x, 2) + a3 * :math.pow(x, 3)

    # IO.inspect(y, label: "y")
    # IO.inspect(x, label: "x")
    # IO.inspect(hour_value - y, label: "hour_value")
    hour_value - y / 60
    # hour_value
  end
end
