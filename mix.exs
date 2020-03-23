defmodule Uchukuzi.MixProject do
  use Mix.Project

  def project do
    [
      app: :uchukuzi,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # DOCS - mix docs
      name: "Uchukuzi",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Uchukuzi.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:topo, "~> 0.4.0"},
      {:distance, "~> 0.2.1"},
      {:envelope, "~> 1.1"},
      # ----- DOCS --------
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp docs do
    [
      main: "Uchukuzi",
      extras: ["README.md"],
      groups_for_modules: [
        "School APIs": [
          Uchukuzi.School.Bus,
          Uchukuzi.School.Bus.FuelRecord,
          Uchukuzi.School.Bus.PerformedRepair,
          Uchukuzi.School.Bus.ScheduledRepair,
          Uchukuzi.School.BusServer,
          Uchukuzi.School.BusServer.State,
          Uchukuzi.School.BusStop,
          Uchukuzi.School.BusSupervisor,
          Uchukuzi.School.BusesSupervisor,
          Uchukuzi.School.Device,
          Uchukuzi.School.Route,
          Uchukuzi.School.School
        ],
        Roles: [
          Uchukuzi.Roles.Assistant,
          Uchukuzi.Roles.Guardian,
          Uchukuzi.Roles.Household,
          Uchukuzi.Roles.Manager,
          Uchukuzi.Roles.Student
        ],
        Tracking: [
          Uchukuzi.Tracking.Geofence,
          Uchukuzi.Tracking.StudentActivity,
          Uchukuzi.Tracking.Trip,
          Uchukuzi.Tracking.TripSupervisor,
          Uchukuzi.Tracking.TripTracker,
          Uchukuzi.Tracking.World
        ],
        World: [
          Uchukuzi.World.Tile,
          Uchukuzi.World.TileServer,
          Uchukuzi.World.TileServer.BusState,
          Uchukuzi.World.TileSupervisor,
          Uchukuzi.World.ETAGraph,
          Uchukuzi.World.WorldManager,
          Uchukuzi.World.WorldSupervisor
        ]
      ]
    ]
  end
end
