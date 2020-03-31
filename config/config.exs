use Mix.Config

config :uchukuzi,
  ecto_repos: [Uchukuzi.Repo]

import_config "#{Mix.env()}.exs"
