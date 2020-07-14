Push: git push heroku master

heroku run "POOL_SIZE=2 mix ecto.migrate"


heroku ps:exec 
iex --sname console --remsh server@${HOSTNAME}


docker create --name uchukuzi -e POSTGRES_PASSWORD=postgres -p 5432:5432  postgres
docker update --restart=on-failure uchukuzi
docker start uchukuzi
sleep 10
mix ecto.create
mix ecto.migrate
iex -S mix phx.server



Reset giga;ixir

Ecto.Migrator.run(Uchukuzi.Repo, Application.app_dir(:uchukuzi, "priv/repo/migrations"), :down, [all: true])
Ecto.Migrator.run(Uchukuzi.Repo, Application.app_dir(:uchukuzi, "priv/repo/migrations"), :up, [all: true])