defmodule Uchukuzi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Uchukuzi.Repo, []},
      {Registry, keys: :unique, name: Uchukuzi.Registry},
      Uchukuzi.School.BusesSupervisor,
      Uchukuzi.World.WorldSupervisor
    ]

    :ets.new(Uchukuzi.Tracking.TripTracker.tableName(), [:public, :named_table])

    opts = [strategy: :one_for_one, name: Uchukuzi.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
