defmodule Uchukuzi.ETA do
  alias Uchukuzi.ETA.LearnerWorker
  alias Uchukuzi.DiskDB

  def start_up() do
    Uchukuzi.DiskDB.createTable(__MODULE__)
  end

  def insert(_, _, cross_time) when cross_time > 2400 do
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
    Uchukuzi.DiskDB.get_all(Uchukuzi.ETA)
    |> Enum.map(&learn_on_tile/1)
    |> (fn x ->
          IO.inspect(label: "Trained #{Enum.count(x)}")
          x
        end).()
  end

  def learn_on_tile({k, v}) do
    LearnerWorker.learn(k, v)
  end

  def coordinate_hash(coordinate) do
    :crypto.hash(:sha, "#{coordinate.lat}_#{coordinate.lng}")
    |> Base.encode32()
  end
end
