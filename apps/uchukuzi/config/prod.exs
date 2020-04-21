use Mix.Config

config :uchukuzi, Uchukuzi.Repo,
  adapter: Ecto.Adapters.Postgres,
  url:  System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: true

# config :uchukuzi, Uchukuzi.Repo,
#   database: "uchukuzi_repo",
#   username: "postgres",
#   password: "postgres",
#   hostname: "localhost"


# config :a, AWeb.Endpoint,
#   secret_key_base: "+KxyFNRTdSMSGUDyakrnw0w+SSpJWIYgfesw4xHJslCLRtH/PrO6l4zM2Hxt0DLH"

# # Configure your database
# config :a, A.Repo,
#   username: "postgres",
#   password: "postgres",
#   database: "a_prod",
#   pool_size: 15
