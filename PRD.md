# MyPacer - Product Requirements Document (PRD)

## 1. Vision Produit
MyPacer est un outil web pragmatique destiné aux coureurs et entraîneurs. Il est né d'un constat simple : les calculateurs d'allure sont souvent mal conçus, et la recherche d'athlètes sur le site officiel de la fédération (athle.fr) est laborieuse.

**Proposition de valeur :** Offrir une table d'allure claire et configurable, enrichie par les données réelles des athlètes récupérées via un moteur de recherche simplifié.

## 2. Piliers Fonctionnels

### A. Le Calculateur d'Allure (The Foundation)
Fournir une matrice de référence lisible pour l'entraînement.
* **Table Dynamique :** Génération instantanée croisant Allure (min/km), Vitesse (km/h) et Temps.
* **Personnalisation :**
    * Plage d'allure (Min/Max) et incrément précis (ex: 5s).
    * Ajout de distances personnalisées à la volée (ex: 80m, 12km) en plus des standards (10km, Marathon).
* **Contexte VMA :** Affichage optionnel de l'intensité en % de VMA.

### B. Moteur de Recherche "Smart Search" (The Pain Killer)
Résoudre la friction de la recherche sur le site officiel.
* **Recherche Unifiée :** Un champ unique remplaçant les formulaires multi-critères (Nom + Prénom + Année...).
* **Fuzzy Matching :** Capacité à trouver un athlète malgré une orthographe approximative ou partielle (via indexation locale).
* **Accès Direct :** Lien immédiat vers la fiche officielle sur `athle.fr`.

### C. Analyse & Visualisation (The Insight)
Contextualiser la performance en projetant les données réelles sur la théorie.
* **Benchmarking Visuel :** Affichage des records personnels (RP) directement dans la table d'allure (surbrillance).
* **Comparaison Multi-Athlètes :** Superposition des records de plusieurs coureurs pour identifier les forces relatives (ex: Athlète A meilleur sur court, Athlète B meilleur sur long).
* **Cohérence de Profil :** Visualisation de l'alignement des records d'un athlète pour détecter des anomalies de performance ou des marges de progression.

## 3. Stratégie de Données (Le Rôle du Scraper)

Pour offrir cette expérience fluide ("Smart Search"), MyPacer ne peut pas dépendre uniquement d'appels en direct vers `athle.fr` qui est lent et strict sur la recherche. Nous adoptons une stratégie hybride :

### A. Données Froides (Indexation)
* **Rôle du Scraper :** Alimenter une base de données locale (PostgreSQL) contenant l'annuaire des licenciés.
* **Fréquence :**
    * *Initial Load :* Historique complet (2004-2025).
    * *Update :* Mise à jour incrémentale (saison en cours) via Cron.
* **Objectif :** Permettre la recherche instantanée et floue (Trigram search) sans interroger le site fédéral.

### B. Données Chaudes (Performance)
* **Rôle de l'API :** Récupérer les performances (chronos) à la demande.
* **Processus :** Une fois l'athlète identifié via la recherche locale, l'application interroge `athle.fr` en temps réel pour extraire ses records à jour.
* **Objectif :** Garantir que les temps affichés dans le tableau sont toujours les plus récents.
