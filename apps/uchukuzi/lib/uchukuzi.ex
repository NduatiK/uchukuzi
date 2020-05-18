defmodule Uchukuzi do
  @moduledoc """
  Documentation for Uchukuzi.
  """

  def service_name(service_id) do
    {:via, Registry, {Uchukuzi.Registry, service_id}}
  end

  def flush_trips() do
    Uchukuzi.Repo.all(Uchukuzi.Tracking.Trip)
    |> Enum.map(&Uchukuzi.Repo.delete!/1)

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
end
