if [[ -d "/mnt/backup/logs/fl" ]]
then
	git pull
	docker-compose up --build
	docker image prune -a --filter "until=24h"
fi
