#!/usr/bin/env bash
# À lancer sur le NAS (crontab). Récupère les derniers backups de prod via la
# clé dédiée (commande forcée export-latest-backups.sh) et garde 90 jours.
set -euo pipefail

dest="${DEST:-$HOME/data/mypacer-backups}"
key="${KEY:-$HOME/.ssh/mypacer_backup}"
keep_days="${KEEP_DAYS:-90}"

mkdir -p "$dest"
partial="$dest/.incoming.tar"
trap 'rm -f "$partial"' EXIT
ssh -i "$key" -o BatchMode=yes -o IdentitiesOnly=yes cyril@mypacer.fr > "$partial"
tar -tf "$partial" > /dev/null
tar -xf "$partial" -C "$dest"

find "$dest" -type f \( -name '*.dump' -o -name '*.db' \) -mtime +"$keep_days" -delete
echo "✅ $(date -Is) backups récupérés : $(tar -tf "$partial" | tr '\n' ' ')"
