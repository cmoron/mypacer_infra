#!/usr/bin/env bash
# Commande forcée de la clé SSH du NAS : envoie sur stdout un tar contenant
# le dernier dump PostgreSQL et le dernier snapshot cockpit DB. Lecture seule.
set -euo pipefail
cd "$HOME"

latest() { find "$1" -maxdepth 1 -name "$2" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-; }

pg="$(latest backups/postgres 'mypacer-*.dump')"
cockpit="$(latest var/backups 'cockpit-daily-*.db')"
test -n "$pg" || { echo "aucun dump PostgreSQL" >&2; exit 1; }
test -n "$cockpit" || { echo "aucun snapshot cockpit" >&2; exit 1; }
tar -cf - "$pg" "$cockpit"
