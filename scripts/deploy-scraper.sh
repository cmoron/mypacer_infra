#!/usr/bin/env bash
# Commande forcée de la clé de déploiement GitHub du scraper : quel que soit
# le script envoyé, elle ne peut que redéployer le conteneur scraper.
set -euo pipefail
cd "$(dirname "$0")/.."

docker-compose -f docker-compose.prod.yml pull scraper
# --no-deps : ne jamais recréer db au passage.
docker-compose -f docker-compose.prod.yml up -d --no-deps scraper
sleep 5

status=$(docker inspect -f '{{.State.Status}}' mypacer-scraper)
docker inspect -f 'image={{.Image}} started={{.State.StartedAt}}' mypacer-scraper
if [ "$status" != "running" ]; then
  echo "❌ Scraper container is not running! Status: $status"
  exit 1
fi
echo "✅ Scraper container is running!"
