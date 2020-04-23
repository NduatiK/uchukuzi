Push: git push heroku master

heroku run "POOL_SIZE=2 mix ecto.migrate"


heroku ps:exec 
iex --sname console --remsh server@${HOSTNAME}