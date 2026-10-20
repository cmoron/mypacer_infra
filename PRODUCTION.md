# Production MyPacer

Runbook du produit grand public servi sur <https://mypacer.fr>. MyPacer Club a
son propre déploiement systemd dans le dépôt `mypacer-club`.

## Architecture déployée

| Service       | Conteneur         |        Port hôte | Persistance      |
| ------------- | ----------------- | ---------------: | ---------------- |
| PostgreSQL 16 | `mypacer-db`      | `127.0.0.1:5432` | volume `db_data` |
| Scraper       | `mypacer-scraper` |                — | volume de logs   |
| API           | `mypacer-api`     | `127.0.0.1:8000` | PostgreSQL       |
| Web           | `mypacer-web`     | `127.0.0.1:8080` | stateless        |

Nginx termine TLS et route `/api/` vers l'API, le reste vers le frontend.

## Accès serveur

```bash
ssh cyril@mypacer.fr
cd /home/cyril/src/mypacer/mypacer_infra
docker-compose -f docker-compose.prod.yml ps
```

Ce serveur utilise Docker Compose v1.29.2. Les commandes de ce runbook emploient
donc `docker-compose`.

## Release normale

Chaque service se publie depuis son propre dépôt :

1. CI verte sur `main` et staging validé.
2. Créer puis pousser un tag `vX.Y.Z` dans le dépôt du service.
3. Le workflow Docker publie `vX.Y.Z-prod` et `latest-prod` sur GHCR.
4. `deploy-prod.yml` se déclenche, pull l'image et redémarre le service.
5. Vérifier le workflow et les healthchecks.

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
gh run list --limit 10
gh run watch <run-id>
```

Une publication n'est terminée qu'après succès du workflow de déploiement et du
healthcheck. Le chemin SSH manuel n'est qu'un diagnostic ou un rollback.

## Vérifications

```bash
curl --fail https://mypacer.fr/
curl --fail https://mypacer.fr/api/health

ssh cyril@mypacer.fr
cd /home/cyril/src/mypacer/mypacer_infra
docker-compose -f docker-compose.prod.yml ps
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
docker-compose -f docker-compose.prod.yml logs --tail=100 api
```

La date `last_update` exposée par `/api/database_status` décrit les lignes de la
base, pas l'exécution du cron. Pour vérifier le scraper, consulter ses logs :

```bash
docker top mypacer-scraper
docker logs --tail=200 mypacer-scraper
```

## Backup PostgreSQL

Un timer systemd utilisateur lance `scripts/backup-postgres.sh` chaque nuit à
02h30 : dump `-Fc` dans `~/backups/postgres/`, vérifié par
`pg_restore --list`, 14 dumps gardés. Installation (une fois, après `git pull`) :

```bash
cd /home/cyril/src/mypacer/mypacer_infra
mkdir -p ~/.config/systemd/user
install -m 0644 systemd/mypacer-pg-backup.service systemd/mypacer-pg-backup.timer \
  ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user start mypacer-pg-backup.service   # premier dump immédiat
journalctl --user -u mypacer-pg-backup.service -n 20
systemctl --user enable --now mypacer-pg-backup.timer
```

### Copie hors machine (NAS)

Le NAS (`nas`, Debian) tire chaque nuit à 05h00 le dernier dump PostgreSQL et le
dernier snapshot cockpit Club vers `~/data/mypacer-backups/` (90 jours gardés).
Côté prod, sa clé `mypacer_backup` est restreinte dans `~/.ssh/authorized_keys`
à une commande forcée en lecture seule :

```text
restrict,command="/home/cyril/src/mypacer/mypacer_infra/scripts/export-latest-backups.sh" ssh-ed25519 AAAA... mypacer-backup@nas
```

Côté NAS : `crontab -l` contient
`0 5 * * * <infra>/scripts/nas-pull-backups.sh >> ~/data/mypacer-backups/pull.log 2>&1`.
Restauration : `pg_restore` du `.dump`, ou copie du `.db` vers `MPC_DB_PATH`
service dashboard arrêté.

Dump ponctuel avant toute opération de schéma ou restauration :

```bash
ssh cyril@mypacer.fr
cd /home/cyril/src/mypacer/mypacer_infra
mkdir -p "$HOME/backups"
backup="$HOME/backups/mypacer-$(date +%Y%m%d-%H%M%S).dump"
docker-compose -f docker-compose.prod.yml exec -T db \
  sh -lc 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > "$backup"
test -s "$backup" && ls -lh "$backup"
```

Une restauration est destructive : valider le fichier, la cible et une fenêtre
de maintenance avant de lancer `pg_restore`.

## Rollback applicatif

Les variables `WEB_IMAGE_TAG`, `API_IMAGE_TAG` et `SCRAPER_IMAGE_TAG` de `.env`
permettent de revenir à un tag déjà publié.

```bash
cd /home/cyril/src/mypacer/mypacer_infra
# Modifier uniquement le *_IMAGE_TAG du service concerné dans .env.
docker-compose -f docker-compose.prod.yml pull <service>
docker-compose -f docker-compose.prod.yml up -d <service>
docker-compose -f docker-compose.prod.yml ps <service>
```

Après rollback, refaire les healthchecks et documenter le SHA/tag restauré.

## Base de données

`init-db/01-init-schema.sql` est la source de vérité pour un volume neuf. Les
scripts de `init-db/` ne s'exécutent automatiquement qu'à la création d'un
volume vide ; ils ne constituent pas un mécanisme de migration d'une DB
existante.

```bash
docker-compose -f docker-compose.prod.yml exec -T db \
  sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "SELECT count(*) AS athletes FROM athletes; SELECT count(*) AS clubs FROM clubs;"'
```

## Incidents

1. Vérifier `curl`, l'état Compose et les healthchecks Docker.
2. Lire les logs du service fautif avant de le redémarrer.
3. Si une nouvelle image est en cause, pinner le tag précédent.
4. Préserver les volumes et backups ; aucune commande de nettoyage Docker ne
   fait partie du runbook d'incident.
