# 🧪 Staging Environment Guide

## 📋 Overview

L'environnement staging est une réplique de production utilisée pour tester les modifications avant déploiement.

## 🔧 Configuration

### Services

- **Database** : Port 5433 (vs 5432 prod)
- **API** : Port 8001 (vs 8000 prod)
- **Web** : Port 8081 (vs 8080 prod)
- **Scraper** : Désactivé automatiquement (vs cron hebdo prod)

### Images Docker

- **Web** : `latest-staging` (auto-build sur push main)
- **API** : `latest-staging` (auto-build sur push main)
- **Scraper** : `latest-prod` (même image que prod, cron désactivé)

## 🚀 Déploiement

Le staging se déploie **automatiquement** sur push `main` via GitHub Actions :
1. Build de l'image Docker (web ou api)
2. Push vers GHCR
3. SSH vers le serveur
4. Pull de la nouvelle image
5. Redémarrage du container

## 🗄️ Base de données

La base de données staging est **complètement isolée** de la prod :
- Volume séparé : `mypacer_infra_db_staging_data`
- Pas de réinitialisation lors des déploiements
- Peut être réinitialisée manuellement si besoin

### Réinitialiser la DB staging

```bash
docker-compose -f docker-compose.staging.yml down
docker volume rm mypacer_infra_db_staging_data
docker-compose -f docker-compose.staging.yml up -d
```

## 🕷️ Scraper - Lancement manuel

Le scraper staging **ne s'exécute PAS automatiquement** pour éviter de spammer le site FFA.

### Lancer un scraping complet

```bash
# Depuis le serveur
cd /home/cyril/src/mypacer/mypacer_infra

# Lancer le scraping
docker-compose -f docker-compose.staging.yml exec scraper-staging \
  python -m mypacer_scraper.main

# Voir les logs
docker-compose -f docker-compose.staging.yml logs -f scraper-staging
```

### Lancer uniquement une partie

```bash
# Scraper uniquement les clubs
docker-compose -f docker-compose.staging.yml exec scraper-staging \
  python -m mypacer_scraper.scraper.clubs_scraper

# Scraper uniquement les athlètes
docker-compose -f docker-compose.staging.yml exec scraper-staging \
  python -m mypacer_scraper.scraper.athletes_scraper
```

### Vérifier l'état de la DB après scraping

```bash
docker-compose -f docker-compose.staging.yml exec db-staging \
  psql -U mypacer_user -d mypacer_staging -c "SELECT * FROM v_athletes_stats;"

docker-compose -f docker-compose.staging.yml exec db-staging \
  psql -U mypacer_user -d mypacer_staging -c "SELECT * FROM v_clubs_stats;"
```

## 🔍 Vérification

### Healthchecks

```bash
# Web
curl https://stage.mypacer.fr

# API
curl https://stage.mypacer.fr/api/health
curl https://stage.mypacer.fr/api/database_status

# API docs (Swagger)
open https://stage.mypacer.fr/api/docs
```

### Logs

```bash
cd /home/cyril/src/mypacer/mypacer_infra

# Tous les services
docker-compose -f docker-compose.staging.yml logs -f

# Service spécifique
docker-compose -f docker-compose.staging.yml logs -f web-staging
docker-compose -f docker-compose.staging.yml logs -f api-staging
docker-compose -f docker-compose.staging.yml logs -f scraper-staging
```

### État des containers

```bash
docker-compose -f docker-compose.staging.yml ps
```

## 🔄 Workflow complet

### Tester une modification

1. **Développer** en local avec Docker dev ou directement
2. **Commiter et pusher** sur branche feature
3. **Créer une PR** vers main
4. **Review et merge** la PR
5. **Déploiement auto** sur staging (2-3 min)
6. **Tester** sur https://stage.mypacer.fr
7. **Si OK**, créer un tag pour déployer en prod

### Déployer en production

```bash
# Créer un tag
git tag -a v0.2.0 -m "Release v0.2.0 - Description"
git push origin v0.2.0

# Le workflow auto va :
# 1. Builder l'image vX.Y.Z-prod
# 2. Créer une release GitHub
# 3. (Futur) Déployer en prod automatiquement
```

## ⚠️ Notes importantes

- **Données staging** : Ne sont PAS synchronisées avec prod
- **Scraper staging** : À lancer manuellement (pas de spam FFA)
- **Secrets** : Stockés dans GitHub Environments (staging/production)
- **Rollback** : Changer `*_IMAGE_TAG` dans `.env.staging` et `docker-compose up -d`
