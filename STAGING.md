# Staging MyPacer

Staging est l'environnement de validation du frontend et de l'API sur
<https://stage.mypacer.fr>. Sa base et ses volumes sont séparés de la production.

## Services

| Service    |        Port hôte | Image                                                     |
| ---------- | ---------------: | --------------------------------------------------------- |
| PostgreSQL | `127.0.0.1:5433` | `postgres:16`                                             |
| API        | `127.0.0.1:8001` | `latest-staging`                                          |
| Web        | `127.0.0.1:8081` | `latest-staging`                                          |
| Scraper    |            aucun | `latest-prod`, commande remplacée par `tail -f /dev/null` |

Le scraper ne tourne pas automatiquement en staging afin de limiter les appels
à la FFA.

## Déploiement automatique

Un push sur `main` de `mypacer_web` ou `mypacer_api` déclenche :

1. CI du dépôt ;
2. construction et publication de `latest-staging` ;
3. workflow `deploy.yml` après succès du build Docker ;
4. pull et redémarrage du service staging via SSH ;
5. healthcheck public.

```bash
gh run list --limit 10
gh run watch <run-id>
curl --fail https://stage.mypacer.fr/
curl --fail https://stage.mypacer.fr/api/health
```

## Diagnostic sur l'hôte staging

Le chemin est fourni par le secret GitHub `INFRA_PATH`; ne le recopier dans la
documentation que s'il devient une convention stable.

```bash
cd "$INFRA_PATH"
docker-compose -f docker-compose.staging.yml ps
docker-compose -f docker-compose.staging.yml logs --tail=100 api-staging
docker-compose -f docker-compose.staging.yml logs --tail=100 web-staging
```

## Scraper manuel

Un scraping staging est une opération explicite. Vérifier d'abord la cible DB
et limiter le périmètre lorsque le CLI le permet.

```bash
cd "$INFRA_PATH"
docker-compose -f docker-compose.staging.yml exec scraper-staging \
  ./update_database.sh
```

## Base staging

Le volume `db_staging_data` ne doit pas être supprimé par un workflow de
déploiement. Une réinitialisation est destructive et nécessite un accord
explicite après vérification du nom exact du projet Compose et du volume.

Pour inspecter la base sans exposer ses identifiants :

```bash
docker-compose -f docker-compose.staging.yml exec -T db-staging \
  sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "SELECT count(*) AS athletes FROM athletes; SELECT count(*) AS clubs FROM clubs;"'
```

## Passage en production

Après validation de staging, créer un tag dans le dépôt du service. Le tag
déclenche le build puis le déploiement production décrit dans
[`PRODUCTION.md`](PRODUCTION.md). Aucun copier-coller manuel de l'image staging
vers la production n'est nécessaire.
