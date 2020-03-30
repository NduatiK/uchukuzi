use Mix.Config

config :flotilla, Uchukuzi.Repo,
  database: "uchukuzi_repo_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
