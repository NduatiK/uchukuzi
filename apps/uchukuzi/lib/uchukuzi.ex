defmodule Uchukuzi do
  @moduledoc """
  Convenience methods for Uchukuzi
  """

  def service_name(service_id) do
    {:via, Registry, {Uchukuzi.Registry, service_id}}
  end

  def flush_trips() do
    Uchukuzi.Repo.delete_all(Uchukuzi.Tracking.Trip.ReportCollection)
    Uchukuzi.Repo.delete_all(Uchukuzi.Tracking.Trip)

    flush_servers()
  end

  def flush_servers() do
    Uchukuzi.Repo.all(Uchukuzi.School.Bus)
    |> Enum.map(fn bus ->
      bus
      |> Uchukuzi.Tracking.BusSupervisor.pid_from()
      |> (fn
            nil -> nil
            pid -> GenServer.stop(pid)
          end).()
    end)
  end

  def learn() do
    Uchukuzi.World.ETA.rebuild_models()
  end

  alias Uchukuzi.Tracking.Trip
  import Ecto.Query

  def export_trips_to_json_files() do
    Path.expand("exports")
    |> File.rm_rf()
    |> IO.inspect()

    Path.expand("exports")
    |> File.mkdir()

    from(t in Trip,
      preload: [:report_collection]
    )
    |> Uchukuzi.Repo.all()
    |> Enum.map(fn trip ->
      Task.async(fn ->
        trip.report_collection.reports
        |> Enum.map(fn report ->
          %{
            time: report.time,
            lng: report.location.lng,
            lat: report.location.lat
          }
        end)
      end)
    end)
    |> Enum.map(& Task.await(&1, 5000))
    |> Enum.map(fn reports ->
      reports
      |> Enum.sort_by(& &1.time)
    end)
    |> Enum.with_index()
    |> Enum.map(fn {reports, index} ->
      {index, reports}
    end)
    |> Enum.map(fn {index, entries} ->
      {:ok, file} =
        File.open("./exports/" <> Integer.to_string(index) <> ".json", [:write, :append, :utf8])

      content =
        entries
        |> Enum.map(fn entry ->
          entry
          |> Jason.encode!()
        end)
        |> Enum.join("\n")

      IO.write(file, content)
    end)

    # Uchukuzi.World.ETA.rebuild_models()
  end
end
