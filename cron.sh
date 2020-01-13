# run every 10 minutes
# map files to webdirectory

git pull
docker-compose up --build
docker image prune -a --filter "until=24h"