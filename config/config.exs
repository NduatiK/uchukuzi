use Mix.Config

config :flotilla,
  ecto_repos: [Uchukuzi.Repo]

import_config "#{Mix.env()}.exs"
