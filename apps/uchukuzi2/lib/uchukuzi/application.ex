defmodule Uchukuzi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      %{id: PubSub, start: {PubSub, :start_link, []}},
      {Uchukuzi.Repo, []},
      {Registry, keys: :unique, name: Uchukuzi.Registry},
      Uchukuzi.Tracking.BusesSupervisor,
      Uchukuzi.World.WorldSupervisor,
      Uchukuzi.World.ETA.ETASupervisor,
      Uchukuzi.Scheduler
    ]

    :ets.new(Uchukuzi.Tracking.TripTracker.tableName(), [:public, :named_table])

    opts = [strategy: :one_for_one, name: Uchukuzi.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
