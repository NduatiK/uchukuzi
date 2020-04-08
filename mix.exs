defmodule Uchukuzi.MixProject do
  use Mix.Project

  def project do
    [
      app: :uchukuzi,
      description: "School bus tracking on steroids",
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # config_path: "config/config.exs",

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
      {:penelope, "~> 0.4"},
      {:eqrcode, "~> 0.1.7"},

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
          Uchukuzi.Tracking.BusServer,
          Uchukuzi.Tracking.BusServer.State,
          Uchukuzi.School.BusStop,
          Uchukuzi.Tracking.BusSupervisor,
          Uchukuzi.Tracking.BusesSupervisor,
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
          Uchukuzi.Common.Geofence,
          Uchukuzi.Tracking.StudentActivity,
          Uchukuzi.Tracking.Trip,
          Uchukuzi.Tracking.TripSupervisor,
          Uchukuzi.Tracking.TripTracker
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
          Uchukuzi.Common.Geofence
        ]
      ]
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
