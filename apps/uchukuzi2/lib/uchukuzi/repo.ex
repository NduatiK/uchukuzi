defmodule Uchukuzi.Repo do
  use Ecto.Repo,
    otp_app: :uchukuzi,
    adapter: Ecto.Adapters.Postgres
end
