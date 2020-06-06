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

  def insert(_, _, cross_time) when cross_time > 2400 do
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
      [prediction] = predict_cross_time(tile, hour_value)

      prediction = adjust_by_index(prediction, index)

      hour_value = hour_value + prediction / 3600 + 24

      hour_value =
        cond do
          hour_value >= 24 ->
            hour_value - 24

          hour_value < 0 ->
            hour_value + 24

          true ->
            hour_value
        end

      {hour_value, [{tile, hour_value} | acc]}
    end)
  end

  def adjust_by_index(prediction, x) do
    # prediction - (10.15 + 0.52 * x + 0.0034 * x * x)

    a0 = 0.2731
    a1 = 2.4603
    a2 = -0.0934
    a3 = 0.0016
    y = a0 + a1 * x + a2 * :math.pow(x, 2) + a3 * :math.pow(x, 3)

    prediction - y * 2.5

    # a = 1.27
    # b = -2.1
    # prediction - (a * index + b)
  end
end
