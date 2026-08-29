# MyPacer Infrastructure

Infrastructure Docker Compose du produit grand public MyPacer : PostgreSQL,
scraper FFA, API FastAPI et frontend Svelte.

## Documentation

- [`PRODUCTION.md`](PRODUCTION.md) : release, vérifications, backup et rollback.
- [`STAGING.md`](STAGING.md) : déploiement automatique et contrôles staging.
- [`init-db/README.md`](init-db/README.md) : initialisation d'un volume PostgreSQL
  vide. Le schéma de référence est `init-db/01-init-schema.sql`.
- [`PRD.md`](PRD.md) : vision du produit grand public, pas un runbook.

## Architecture

```text
Internet ──HTTPS──▶ nginx hôte
                     ├── /api/ ──▶ mypacer-api:8000 ──▶ PostgreSQL 16
                     └── / ─────▶ mypacer-web:8080
                                           ▲
FFA ──scrape live──▶ API                    │
FFA ──batch────────▶ mypacer-scraper ───────┘
```

Le scraper alimente l'index de recherche PostgreSQL ; l'API récupère les
performances individuelles à la demande. MyPacer Club est déployé séparément et
n'appartient pas à ce Compose.

## Environnements

| Environnement | Compose                      | Images                                      |
| ------------- | ---------------------------- | ------------------------------------------- |
| Production    | `docker-compose.prod.yml`    | `latest-prod` ou tag `vX.Y.Z-prod`          |
| Staging       | `docker-compose.staging.yml` | web/API `latest-staging`, scraper sans cron |

Sur le serveur de production, le dépôt vit dans
`/home/cyril/src/mypacer/mypacer_infra` et Docker Compose v1.29.2 est installé :
utiliser `docker-compose`, avec tiret. Les postes disposant de Compose v2 peuvent
utiliser l'équivalent `docker compose`.

## Configuration

```bash
cp .env.example .env
```

Les secrets restent uniquement dans le fichier `.env` serveur. Les variables
`*_IMAGE_TAG` permettent de pinner ou restaurer une image précise.

```bash
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d
docker-compose -f docker-compose.prod.yml ps
```

## CI/CD

- Un push sur `main` de `mypacer_web` ou `mypacer_api` construit
  `latest-staging`, puis déploie automatiquement staging.
- Un tag `vX.Y.Z` construit les images de production et déclenche le workflow
  `deploy-prod.yml` du dépôt concerné.
- `mypacer_scraper` suit le même flux de release par tag ; son cron staging est
  désactivé.
- Ce dépôt décrit l'orchestration. Les workflows vivent dans les dépôts des
  services.

## Vérification rapide

```bash
curl --fail https://mypacer.fr/
curl --fail https://mypacer.fr/api/health
curl --fail https://stage.mypacer.fr/
curl --fail https://stage.mypacer.fr/api/health
```

Ne recopier ni version, ni volume de données, ni uptime dans ce README : ces
valeurs doivent être lues sur le service au moment du diagnostic.

## Dépôts

- [mypacer_web](https://github.com/cmoron/mypacer_web)
- [mypacer_api](https://github.com/cmoron/mypacer_api)
- [mypacer_scraper](https://github.com/cmoron/mypacer_scraper)
- [mypacer_infra](https://github.com/cmoron/mypacer_infra)
