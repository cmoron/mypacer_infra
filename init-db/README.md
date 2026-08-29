# Initialisation PostgreSQL

`01-init-schema.sql` est la source de vérité du schéma créé pour un nouveau
volume MyPacer.

PostgreSQL exécute les fichiers de ce dossier, dans l'ordre lexical, uniquement
quand son répertoire de données est vide. Modifier ces scripts ne migre pas une
base existante.

## Contenu

`01-init-schema.sql` crée les extensions, tables, index, contraintes, triggers
et vues nécessaires à l'API et au scraper. La copie éventuellement présente
dans un dépôt applicatif sert au développement local et ne devient pas la
référence de production.

## Évolution du schéma

1. Évaluer la compatibilité avec les données et images actuellement déployées.
2. Mettre à jour `01-init-schema.sql` pour les installations neuves.
3. Préparer une migration explicite et sauvegarder la DB avant de l'appliquer à
   un volume existant.
4. Vérifier le schéma, l'API et le scraper sur staging.
5. Livrer les images compatibles avant ou avec la migration production.

## Vérification

Sur le serveur de production, qui utilise Docker Compose v1 :

```bash
cd /home/cyril/src/mypacer/mypacer_infra
docker-compose -f docker-compose.prod.yml exec -T db \
  sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\\dt"'
docker-compose -f docker-compose.prod.yml exec -T db \
  sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "SELECT count(*) AS athletes FROM athletes; SELECT count(*) AS clubs FROM clubs;"'
```

Pour staging, utiliser les mêmes commandes avec
`docker-compose.staging.yml` et le service `db-staging`.

## Réinitialisation

La suppression d'un volume détruit toutes ses données. Elle n'appartient pas au
runbook courant : vérifier l'environnement, le nom Compose, le volume exact et
un backup restaurable, puis obtenir un accord explicite avant toute
réinitialisation.
