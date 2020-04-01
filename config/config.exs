use Mix.Config

import_config("../../uchukuzi/config/config.exs")

config :uchukuzi_interface, UchukuziInterfaceWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "3CuzHDvMrRgq2EWUHWD2tiJiprpdnr6HpP2VQeqEQrl3dSINIwdxiKdt+Uy7BLyQ",
  render_errors: [view: UchukuziInterfaceWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: UchukuziInterface.PubSub, adapter: Phoenix.PubSub.PG2]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
