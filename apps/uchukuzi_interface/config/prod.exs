use Mix.Config

config :uchukuzi_interface, UchukuziInterfaceWeb.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [scheme: "https", host: "uchukuzi.herokuapp.com", port: 443],
  force_ssl: [rewrite_on: [:x_forwarded_proto]],  secret_key_base: Map.fetch!(System.get_env(), "SECRET_KEY_BASE"),
  server: true,
  cache_static_manifest: "priv/static/cache_manifest.json"
