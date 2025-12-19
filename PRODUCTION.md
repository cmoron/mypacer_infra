# 🚀 Production Environment Guide

## 📋 Overview

L'environnement de production héberge l'application **MyPacer** en ligne sur https://mypacer.fr.

## 🔧 Configuration

### Services

- **Database** : Port 5432 (PostgreSQL 16)
- **API** : Port 8000 (FastAPI)
- **Web** : Port 8080 (Nginx + Svelte SPA)
- **Scraper** : Cron automatique (chaque dimanche 3h)

### Images Docker

- **Web** : `vX.Y.Z-prod` ou `latest-prod` (build sur tag)
- **API** : `vX.Y.Z-prod` ou `latest-prod` (build sur tag)
- **Scraper** : `vX.Y.Z-prod` ou `latest-prod` (build sur tag)

## 🚀 Déploiement

Le déploiement en production se fait **manuellement** via création de tag Git :

### Workflow de déploiement

1. **Tester en staging** : Vérifier que tout fonctionne sur https://stage.mypacer.fr
2. **Créer un tag** : `git tag -a vX.Y.Z -m "Description"`
3. **Push le tag** : `git push origin vX.Y.Z`
4. **GitHub Actions** : Build automatique de l'image `vX.Y.Z-prod` + `latest-prod`
5. **Déploiement manuel** : SSH sur le serveur et mise à jour

### Déployer une nouvelle version

```bash
# Sur votre poste local
cd /path/to/mypacer_web  # ou mypacer_api, mypacer_scraper
git tag -a v0.3.0 -m "Release v0.3.0 - Description des changements"
git push origin v0.3.0

# Attendre que le workflow GitHub Actions termine (2-3 min)
# Vérifier sur https://github.com/cmoron/mypacer_web/actions

# SSH sur le serveur de production
ssh user@prod-server
cd PATH/mypacer/mypacer_infra

# Option 1 : Mettre à jour vers une version spécifique
# Modifier .env pour définir WEB_IMAGE_TAG=v0.3.0-prod
vim .env

# Option 2 : Utiliser latest-prod (par défaut)
# Le .env utilise ${WEB_IMAGE_TAG:-latest-prod}

# Pull de la nouvelle image
docker-compose -f docker-compose.prod.yml pull web

# Redémarrage du service
docker-compose -f docker-compose.prod.yml up -d web

# Vérifier les logs
docker-compose -f docker-compose.prod.yml logs -f web
```

### Mise à jour multiple services

```bash
# Exemple : Mise à jour API + Scraper en même temps
docker-compose -f docker-compose.prod.yml pull api scraper
docker-compose -f docker-compose.prod.yml up -d api scraper
docker-compose -f docker-compose.prod.yml logs -f api scraper
```

## 🗄️ Base de données

La base de données de production contient **les données réelles** :
- Volume persistant : `mypacer_infra_db_data`
- **940,868 athlètes** licenciés FFA
- **3,419 clubs** actifs
- **Aucune réinitialisation** lors des déploiements

### Backup de la base de données

**⚠️ CRITIQUE** : Toujours faire un backup avant une opération sensible.

```bash
# Backup complet (format custom - recommandé)
docker-compose -f docker-compose.prod.yml exec db \
  pg_dump -U mypacer_user -d mypacer_prod -Fc \
  > ~/backups/mypacer_prod_$(date +%Y%m%d_%H%M%S).dump

# Backup SQL plain text (plus lisible)
docker-compose -f docker-compose.prod.yml exec db \
  pg_dump -U mypacer_user -d mypacer_prod \
  > ~/backups/mypacer_prod_$(date +%Y%m%d_%H%M%S).sql

# Vérifier la taille du backup
ls -lh ~/backups/mypacer_prod_*.dump
```

### Restauration depuis un backup

```bash
# Restaurer depuis un backup custom format
cat ~/backups/mypacer_prod_YYYYMMDD_HHMMSS.dump | \
  docker-compose -f docker-compose.prod.yml exec -T db \
  pg_restore -U mypacer_user -d mypacer_prod --clean

# Restaurer depuis un backup SQL
cat ~/backups/mypacer_prod_YYYYMMDD_HHMMSS.sql | \
  docker-compose -f docker-compose.prod.yml exec -T db \
  psql -U mypacer_user -d mypacer_prod
```

### Statistiques de la base

```bash
# Nombre d'athlètes et clubs
docker-compose -f docker-compose.prod.yml exec db \
  psql -U mypacer_user -d mypacer_prod -c "
    SELECT
      (SELECT COUNT(*) FROM athletes) as nb_athletes,
      (SELECT COUNT(*) FROM clubs) as nb_clubs;
  "

# Dernière mise à jour (scraping)
docker-compose -f docker-compose.prod.yml exec db \
  psql -U mypacer_user -d mypacer_prod -c "
    SELECT MAX(updated_at) as last_update FROM athletes;
  "

# Top 10 clubs par nombre d'athlètes
docker-compose -f docker-compose.prod.yml exec db \
  psql -U mypacer_user -d mypacer_prod -c "
    SELECT club_name, COUNT(*) as nb_athletes
    FROM athletes
    WHERE club_name IS NOT NULL
    GROUP BY club_name
    ORDER BY nb_athletes DESC
    LIMIT 10;
  "
```

## 🕷️ Scraper - Automatique hebdomadaire

Le scraper de production s'exécute **automatiquement** chaque dimanche à 3h du matin via Supercronic.

### Vérifier l'état du scraper

```bash
# Voir les derniers logs du scraper
docker-compose -f docker-compose.prod.yml logs --tail=100 scraper

# Voir si le cron tourne
docker-compose -f docker-compose.prod.yml exec scraper ps aux | grep super

# Voir la configuration cron
docker-compose -f docker-compose.prod.yml exec scraper cat /etc/cron.d/scraper
```

### Lancer un scraping manuel (exceptionnel)

```bash
# Lancer un scraping complet manuellement
docker-compose -f docker-compose.prod.yml exec scraper \
  python -m mypacer_scraper.main

# Voir les logs en temps réel
docker-compose -f docker-compose.prod.yml logs -f scraper
```

### Désactiver temporairement le scraper

```bash
# Arrêter le scraper (cron ne tournera plus)
docker-compose -f docker-compose.prod.yml stop scraper

# Redémarrer le scraper
docker-compose -f docker-compose.prod.yml start scraper
```

## 🔍 Vérification et Monitoring

### Healthchecks

```bash
# Web (Frontend)
curl https://mypacer.fr
curl -I https://mypacer.fr  # Vérifier le code HTTP 200

# API
curl https://mypacer.fr/api/health
# Réponse attendue : {"status":"healthy","service":"mypacer-api"}

curl https://mypacer.fr/api/database_status
# Réponse attendue : {"num_clubs":3419,"num_athletes":940868,"last_update":"..."}

# API docs (Swagger)
curl https://mypacer.fr/api/docs
```

### Logs

```bash
cd PATH/mypacer/mypacer_infra

# Tous les services
docker-compose -f docker-compose.prod.yml logs -f

# Service spécifique
docker-compose -f docker-compose.prod.yml logs -f web
docker-compose -f docker-compose.prod.yml logs -f api
docker-compose -f docker-compose.prod.yml logs -f scraper
docker-compose -f docker-compose.prod.yml logs -f db

# Dernières 100 lignes
docker-compose -f docker-compose.prod.yml logs --tail=100 api

# Logs depuis une date
docker-compose -f docker-compose.prod.yml logs --since="2024-12-19T10:00:00" api
```

### État des containers

```bash
# Voir tous les containers et leur état
docker-compose -f docker-compose.prod.yml ps

# Vérifier les healthchecks Docker
docker ps --format "table {{.Names}}\t{{.Status}}"

# Utilisation ressources
docker stats mypacer-web mypacer-api mypacer-db mypacer-scraper
```

### Monitoring système

```bash
# Espace disque
df -h

# Taille des volumes Docker
docker system df -v

# Taille du volume de la DB
du -sh /var/lib/docker/volumes/mypacer_infra_db_data

# RAM et CPU
htop  # ou top
```

## 🔄 Workflow complet de release

### 1. Développement et tests

```bash
# Développer en local
# Tester en local avec Docker dev

# Commiter et pusher sur branche feature
git checkout -b feature/nouvelle-fonctionnalite
git add .
git commit -m "feat: description"
git push origin feature/nouvelle-fonctionnalite

# Créer une Pull Request vers main
# Review + tests CI/CD passent
# Merge dans main
```

### 2. Test en staging (automatique)

```bash
# Le merge dans main déclenche :
# - Build de l'image latest-staging
# - Déploiement auto sur stage.mypacer.fr

# Tester manuellement sur staging
open https://stage.mypacer.fr
```

### 3. Release en production (manuel)

```bash
# Vérifier que staging fonctionne correctement
# Créer un tag de release
git checkout main
git pull origin main

# Incrémentation sémantique : MAJOR.MINOR.PATCH
# - MAJOR : breaking changes (1.0.0 → 2.0.0)
# - MINOR : nouvelles fonctionnalités (0.2.0 → 0.3.0)
# - PATCH : bug fixes (0.2.0 → 0.2.1)

git tag -a v0.3.0 -m "Release v0.3.0

## Nouvelles fonctionnalités
- Feature 1
- Feature 2

## Corrections
- Fix 1
- Fix 2

## Améliorations
- Amélioration 1
"

git push origin v0.3.0

# Le workflow GitHub Actions va :
# - Builder l'image v0.3.0-prod
# - Publier sur GHCR
# - Créer une release GitHub
```

### 4. Déploiement en production

```bash
# SSH sur le serveur de production
ssh user@prod-server
cd PATH/mypacer/mypacer_infra

# Backup de la DB (CRITIQUE avant mise à jour majeure)
docker-compose -f docker-compose.prod.yml exec db \
  pg_dump -U mypacer_user -d mypacer -Fc \
  > ~/backups/mypacer_prod_before_v0.3.0_$(date +%Y%m%d_%H%M%S).dump

# Pull de la nouvelle image
docker-compose -f docker-compose.prod.yml pull web

# Redémarrage avec downtime minimal (<5 secondes)
docker-compose -f docker-compose.prod.yml up -d web

# Vérifier les logs
docker-compose -f docker-compose.prod.yml logs -f web

# Vérifier que l'app fonctionne
curl https://mypacer.fr/api/health
curl https://mypacer.fr

# Monitorer pendant 15-30 minutes
docker-compose -f docker-compose.prod.yml logs -f
```

### 5. Rollback (si problème)

```bash
# Méthode 1 : Revenir à la version précédente via tag
# Modifier .env: WEB_IMAGE_TAG=v0.2.0-prod
vim .env

docker-compose -f docker-compose.prod.yml pull web
docker-compose -f docker-compose.prod.yml up -d web

# Méthode 2 : Restaurer depuis un backup DB (si données corrompues)
cat ~/backups/mypacer_prod_before_v0.3.0_*.dump | \
  docker-compose -f docker-compose.prod.yml exec -T db \
  pg_restore -U mypacer_user -d mypacer_prod --clean
```

## 📊 Métriques et Analytics

### Performance API

```bash
# Temps de réponse de l'API (P95 < 500ms objectif)
# Vérifier dans les logs Nginx
sudo tail -f /var/log/nginx/access.log | grep "/api/"

# Ou utiliser un outil de monitoring
# TODO: Configurer Prometheus + Grafana
```

### Usage

```bash
# Nombre de requêtes par jour (logs Nginx)
sudo cat /var/log/nginx/access.log | \
  grep "19/Dec/2025" | wc -l

# Top 10 endpoints API les plus appelés
sudo cat /var/log/nginx/access.log | \
  grep "/api/" | \
  awk '{print $7}' | \
  sort | uniq -c | sort -rn | head -10
```

## ⚠️ Notes importantes

### Sécurité

- **HTTPS obligatoire** : Certificats Let's Encrypt auto-renouvelés
- **Secrets** : Stockés dans `.env` (jamais commité dans Git)
- **Accès SSH** : Clés SSH uniquement (pas de mot de passe)
- **Firewall** : Seuls ports 80, 443, 22 ouverts
- **Updates** : Système et packages à jour régulièrement

### Backups

- **Automatique** : Configurer un cron pour backup quotidien de la DB
- **Rétention** : Garder 30 jours de backups quotidiens
- **Off-site** : Copier les backups sur un serveur distant (rsync, S3, etc.)

### Monitoring à mettre en place

- [ ] UptimeRobot : Monitoring uptime (ping toutes les 5 min)
- [ ] Sentry : Error tracking (exceptions Python/JS)
- [ ] Prometheus + Grafana : Métriques système et applicatives
- [ ] LogRotate : Rotation automatique des logs Docker et Nginx

### Maintenance

- **Restart annuel** : Redémarrer tous les containers 1x par an
- **Updates Docker images** : Vérifier les nouvelles versions de PostgreSQL, etc.
- **Nettoyage Docker** : Supprimer images/volumes inutilisés (`docker system prune`)

### SLA et objectifs

- **Uptime** : 99.9% (objectif = < 8h downtime/an)
- **Latency API** : P95 < 500ms
- **Page load** : P95 < 2s
- **Backup RTO** : < 4h (Recovery Time Objective)
- **Backup RPO** : < 24h (Recovery Point Objective)

## 🆘 Troubleshooting

### Le site ne répond plus

```bash
# Vérifier l'état des containers
docker-compose -f docker-compose.prod.yml ps

# Redémarrer tous les services
docker-compose -f docker-compose.prod.yml restart

# Vérifier Nginx
sudo systemctl status nginx
sudo nginx -t
sudo systemctl restart nginx

# Vérifier les certificats SSL
sudo certbot certificates
```

### La base de données est lente

```bash
# Vérifier les connexions actives
docker-compose -f docker-compose.prod.yml exec db \
  psql -U mypacer_user -d mypacer_prod -c "
    SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active';
  "

# Voir les requêtes lentes
docker-compose -f docker-compose.prod.yml exec db \
  psql -U mypacer_user -d mypacer_prod -c "
    SELECT pid, now() - pg_stat_activity.query_start AS duration, query
    FROM pg_stat_activity
    WHERE state = 'active' AND now() - pg_stat_activity.query_start > interval '5 seconds';
  "

# Analyser les index manquants
# Vérifier les EXPLAIN ANALYZE des requêtes lentes
```

### Espace disque plein

```bash
# Vérifier l'espace
df -h

# Nettoyer les logs Docker
docker system prune -a --volumes  # ATTENTION : supprime aussi les volumes non utilisés

# Rotation manuelle des logs Nginx
sudo truncate -s 0 /var/log/nginx/access.log
sudo truncate -s 0 /var/log/nginx/error.log
```
