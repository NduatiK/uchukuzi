use Mix.Config

config :uchukuzi_interface, UchukuziInterfaceWeb.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [scheme: "https", host: "uchukuzi.gigalixirapp.com", port: 443],
  # force_ssl: [rewrite_on: [:x_forwarded_proto]],  secret_key_base: Map.fetch!(System.get_env(), "SECRET_KEY_BASE"),
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json"



# config :uchukuzi_interface, UchukuziInterfaceWeb.Endpoint,
#   http: [port: 4000],
#   debug_errors: true

# # Do not include metadata nor timestamps in development logs
# config :logger, :console, format: "[$level] $message\n"

# config :uchukuzi_interface, UchukuziInterfaceWeb.Email.Mailer,
#        adapter: Bamboo.LocalAdapter
