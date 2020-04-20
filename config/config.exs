use Mix.Config

config :uchukuzi,
  ecto_repos: [Uchukuzi.Repo]

config :uchukuzi, Uchukuzi.Scheduler,
  jobs: [
    # {"* * * * *", {Uchukuzi.ETA, :rebuild_models, []}}
    {"@daily", {Uchukuzi.ETA, :rebuild_models, []}}
  ]


import_config "#{Mix.env()}.exs"
