defmodule Uchukuzi.MixProject do
  use Mix.Project

  def project do
    [
      app: :uchukuzi,
      description: "School bus tracking on steroids",
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # DOCS - mix docs
      name: "Uchukuzi",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :httpoison],
      mod: {Uchukuzi.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:topo, "~> 0.4.0"},
      {:distance, "~> 0.2.1"},
      {:envelope, "~> 1.1"},
      {:eqrcode, "~> 0.1.7"},

      # ----- ML Related --------
      {:quantum, "~> 3.0-rc"},
      {:export, "~> 0.1.0"},
      {:poolboy, "~> 1.5.1"},
      {:pubsub, "~> 1.0"},

      # ----- WEATHER --------
      {:httpoison, "~> 0.4"},
      {:jason, "~> 1.0"},

      # ----- CRYPTO --------
      {:pbkdf2_elixir, "~> 1.1"},

      # ----- DB --------
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},

      # ----- DOCS --------
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Uchukuzi",
      extras: ["README.md"],
      groups_for_modules: [
        School: [
          Uchukuzi.School.Bus,
          Uchukuzi.School.Bus.FuelRecord,
          Uchukuzi.School.Bus.PerformedRepair,
          Uchukuzi.School.Bus.ScheduledRepair,
          Uchukuzi.School.BusStop,
          Uchukuzi.School.Device,
          Uchukuzi.School.Route,
          Uchukuzi.School.School
        ],
        Roles: [
          Uchukuzi.Roles.CrewMember,
          Uchukuzi.Roles.Manager,
          Uchukuzi.Roles.Guardian,
          Uchukuzi.Roles.Household,
          Uchukuzi.Roles.Student
        ],
        ETA: [
          Uchukuzi.ETA.ETASupervisor,
          Uchukuzi.ETA.LearnerWorker,
          Uchukuzi.ETA.PredictionWorker
        ],
        Tracking: [
          Uchukuzi.Common.Geofence,
          Uchukuzi.Tracking.StudentActivity,
          Uchukuzi.Tracking.Trip,
          Uchukuzi.Tracking.TripSupervisor,
          Uchukuzi.Tracking.TripTracker,
          Uchukuzi.Tracking.BusServer,
          Uchukuzi.Tracking.BusServer.State,
          Uchukuzi.Tracking.BusSupervisor,
          Uchukuzi.Tracking.BusesSupervisor
        ],
        World: [
          Uchukuzi.World.Tile,
          Uchukuzi.World.TileServer,
          Uchukuzi.World.TileServer.BusState,
          Uchukuzi.World.TileSupervisor,
          Uchukuzi.World.ETAGraph,
          Uchukuzi.World.WorldManager,
          Uchukuzi.World.WorldSupervisor
        ],
        Common: [
          Uchukuzi.Common.Report,
          Uchukuzi.Common.Location,
          Uchukuzi.Common.Geofence,
          Uchukuzi.Common.Validation
        ]
      ]
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
