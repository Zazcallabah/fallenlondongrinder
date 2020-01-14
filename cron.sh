#!/bin/bash
if [[ -d "/mnt/backup/logs/fl" ]]
then
	cd "$(dirname "$0")"
	git pull
	docker-compose up --build
	#docker image prune -af --filter "until=24h"
fi
