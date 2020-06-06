defmodule Uchukuzi do
  @moduledoc """
  Documentation for Uchukuzi.
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
end
