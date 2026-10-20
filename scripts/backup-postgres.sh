#!/usr/bin/env bash
# Dump quotidien de la base PostgreSQL de prod (conteneur mypacer-db).
# Vérifie le dump avec pg_restore --list avant de faire tourner la rétention.
set -euo pipefail
umask 077  # dumps privés

backup_dir="${BACKUP_DIR:-$HOME/backups/postgres}"
keep="${KEEP:-14}"
container="${CONTAINER:-mypacer-db}"

mkdir -p "$backup_dir"
target="$backup_dir/mypacer-$(date +%Y%m%d-%H%M%S).dump"
partial="$target.partial"
trap 'rm -f "$partial"' EXIT

docker exec "$container" \
  sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$partial"
test -s "$partial"
docker exec -i "$container" pg_restore --list < "$partial" > /dev/null
mv "$partial" "$target"

# shellcheck disable=SC2012  # noms générés ci-dessus, sans espace
ls -1t "$backup_dir"/mypacer-*.dump | tail -n +"$((keep + 1))" | xargs -r rm --
echo "✅ Dump PostgreSQL : $target ($(du -h "$target" | cut -f1))"
