# 🗄️ Database Initialization Scripts

Ce répertoire contient les scripts SQL d'initialisation de la base de données PostgreSQL pour MyPacer.

## 📋 Comment ça fonctionne

PostgreSQL exécute automatiquement **tous les scripts** de ce répertoire dans l'ordre alphabétique **au premier démarrage** du container (lorsque le volume est vide).

Les scripts sont montés en read-only (`ro`) dans `/docker-entrypoint-initdb.d/` du container PostgreSQL.

## 🔒 Sécurité

**IMPORTANT** : Les scripts d'init ne s'exécutent QU'UNE SEULE FOIS, au premier démarrage avec un volume vide.

Si le volume contient déjà des données, les scripts sont **complètement ignorés**. Cela protège contre :
- ❌ L'écrasement accidentel de données de production
- ❌ La ré-initialisation d'une base existante
- ❌ La perte de données lors d'un redémarrage

## 📁 Scripts disponibles

### `01-init-schema.sql`
Crée le schéma complet de la base de données :
- Extensions PostgreSQL (`pg_trgm`, `unaccent`)
- Tables (`athletes`, `clubs`)
- Index (dont trigram pour recherche floue)
- Fonctions (`normalize_text`)
- Triggers (normalisation automatique)
- Vues (`v_athletes_stats`, `v_clubs_stats`)

## 🔄 Réinitialiser la base de données

Si tu veux vraiment réinitialiser une base (⚠️ **PERTE DE DONNÉES**) :

### Staging
```bash
cd /home/cyril/src/mypacer/mypacer_infra

# 1. Arrêter les containers
docker compose -f docker-compose.staging.yml down

# 2. Supprimer le volume
docker volume rm mypacer_infra_db_staging_data

# 3. Redémarrer (le script d'init va s'exécuter)
docker compose -f docker-compose.staging.yml up -d

# 4. Vérifier les logs de l'init
docker compose -f docker-compose.staging.yml logs db-staging
```

### Production
```bash
cd /home/cyril/src/mypacer/mypacer_infra

# ⚠️ ATTENTION : PERTE TOTALE DES DONNÉES DE PRODUCTION

# 1. Arrêter les containers
docker compose -f docker-compose.prod.yml down

# 2. Supprimer le volume
docker volume rm mypacer_infra_db_data

# 3. Redémarrer (le script d'init va s'exécuter)
docker compose -f docker-compose.prod.yml up -d

# 4. Vérifier les logs de l'init
docker compose -f docker-compose.prod.yml logs db
```

## 🧪 Vérifier que l'init a fonctionné

```bash
# Staging
docker compose -f docker-compose.staging.yml exec db-staging psql -U mypacer_user -d mypacer_staging -c "\dt"
docker compose -f docker-compose.staging.yml exec db-staging psql -U mypacer_user -d mypacer_staging -c "SELECT * FROM v_athletes_stats;"

# Production
docker compose -f docker-compose.prod.yml exec db psql -U mypacer_user -d mypacer -c "\dt"
docker compose -f docker-compose.prod.yml exec db psql -U mypacer_user -d mypacer -c "SELECT * FROM v_athletes_stats;"
```

## 📝 Ajouter de nouveaux scripts

Pour ajouter un nouveau script d'initialisation :

1. Créer un fichier avec un préfixe numéroté : `02-add-new-feature.sql`
2. Les scripts sont exécutés dans l'ordre alphabétique
3. Utiliser `CREATE TABLE IF NOT EXISTS` pour éviter les erreurs
4. Le script ne s'exécutera que sur les nouvelles installations

## 🔗 Relation avec le scraper

Le **scraper** (`mypacer_scraper`) est maintenant responsable UNIQUEMENT de :
- ✅ L'injection des données (scraping FFA)
- ✅ La mise à jour des données existantes

Il ne crée plus le schéma de base de données, c'est le rôle de ces scripts d'init.

## 📚 Source du schéma

Le schéma SQL est extrait de `mypacer_scraper/core/schema.sql` et maintenu dans ce répertoire pour une gestion centralisée de l'infrastructure.
