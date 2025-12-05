# 📚 Solution - Système de Redevances d'Édition

## 🎯 Vue d'ensemble

Ce projet présente une solution complète de modélisation d'un système de calcul de redevances pour un groupe d'édition, conformément aux principes MERISE et aux bonnes pratiques de bases de données relationnelles.

## 📁 Structure du projet

```
solution/
├── mcd.md                  # Modèle Conceptuel de Données (MERISE)
├── mld.md                  # Modèle Logique de Données (ERD)
├── schema.sql              # Script de création des tables et contraintes
├── seed.sql                # Données d'exemple pour tests
├── vues.sql                # 3 vues métier (admin, comptable, auteur)
├── tests.sql               # Suite de tests de validation
├── database.db             # Base SQLite (générée après exécution)
├── README.md               # Cette documentation
├── JUSTIFICATION_TECHNIQUE.md  # Justification des contraintes CHECK et TRIGGERS
├── install.bat             # Script d'installation Windows
├── install.sh              # Script d'installation Linux/Mac
└── diagrams/               # Captures d'écran des diagrammes
```

## 🚀 Installation de SQLite

### Windows

**Option 1: Téléchargement direct**
1. Télécharger SQLite depuis: https://www.sqlite.org/download.html
   - Chercher "Precompiled Binaries for Windows"
   - Télécharger `sqlite-tools-win32-x86-*.zip`
2. Extraire dans `C:\sqlite\`
3. Ajouter au PATH système:
   ```powershell
   setx PATH "%PATH%;C:\sqlite"
   ```

**Option 2: Via Chocolatey**
```powershell
choco install sqlite
```

**Option 3: Via Scoop**
```powershell
scoop install sqlite
```

### Vérification de l'installation
```bash
sqlite3 --version
```

## 📊 Initialisation de la base de données

### Méthode 1: Ligne de commande (recommandée)

```bash
# Se placer dans le dossier solution
cd solution

# Créer la base et exécuter les scripts dans l'ordre
sqlite3 database.db < schema.sql
sqlite3 database.db < seed.sql
sqlite3 database.db < vues.sql

# Lancer les tests de validation
sqlite3 database.db < tests.sql
```

### Méthode 2: Mode interactif

```bash
# Ouvrir SQLite en mode interactif
sqlite3 database.db

# Dans le shell SQLite:
.read schema.sql
.read seed.sql
.read vues.sql
.read tests.sql

# Quitter
.quit
```

### Méthode 3: Script tout-en-un

```bash
# Créer un script init.sh (Linux/Mac) ou init.bat (Windows)
# Contenu pour Windows (init.bat):
@echo off
cd solution
sqlite3 database.db < schema.sql
sqlite3 database.db < seed.sql
sqlite3 database.db < vues.sql
echo Base de donnees initialisee avec succes!
sqlite3 database.db < tests.sql
pause
```

## 🔍 Exploration de la base de données

### Commandes SQLite utiles

```sql
-- Lister toutes les tables
.tables

-- Afficher la structure d'une table
.schema AUTEUR

-- Afficher les données avec des colonnes alignées
.mode column
.headers on

-- Exécuter une requête
SELECT * FROM vue_administrateur;

-- Exporter des résultats en CSV
.mode csv
.output resultats.csv
SELECT * FROM vue_comptable;
.output stdout

-- Afficher toutes les vues
SELECT name FROM sqlite_master WHERE type='view';

-- Afficher tous les triggers
SELECT name FROM sqlite_master WHERE type='trigger';
```

### Requêtes de test rapides

```sql
-- Statistiques globales
SELECT * FROM vue_statistiques_globales;

-- Liste des livres avec leurs auteurs
SELECT * FROM vue_administrateur;

-- Redevances par auteur
SELECT * FROM vue_comptable WHERE statut_collaboration = 'Active';

-- Consultation pour un auteur spécifique (exemple: id_auteur = 1)
SELECT * FROM vue_auteur WHERE id_auteur = 1;

-- Vérifier les pourcentages
SELECT * FROM vue_livres_pourcentage_invalide;
```

## 🎨 Modélisation

### Entités principales

1. **AUTEUR** : Écrivains et contributeurs
2. **LIVRE** : Ouvrages publiés
3. **EDITEUR** : Maisons d'édition
4. **PARTICIPATION** : Association auteur-livre avec droits

### Règles de gestion

- ✅ Un livre doit avoir au moins un auteur
- ✅ La somme des pourcentages de redevance = 100% par livre
- ✅ Un livre est publié par un seul éditeur
- ✅ Les triggers empêchent les données incohérentes
- ✅ Audit automatique avec `created_at` et `updated_at`

### Contraintes d'intégrité

#### Contraintes CHECK (conformes à l'exercice)
- **Unicité** : ISBN, email, SIRET
- **Validation numérique** : 
  - `pourcentage_redevance BETWEEN 0 AND 100`
  - `prix_vente > 0`
  - `nombre_pages > 0`
- **Validation textuelle** :
  - Format email : `email LIKE '%_@_%._%'`
  - Longueur SIRET : `LENGTH(siret) = 14`
  - Rôles autorisés : `role IN ('auteur principal', 'co-auteur', ...)`
- **Validation de cohérence** : `date_fin IS NULL OR date_fin >= date_debut`

#### Contraintes via TRIGGERS (limitation SQLite)
**⚠️ Justification technique** : SQLite interdit les fonctions non-déterministes comme `DATE('now')` dans les CHECK.

**Solution adoptée** : Triggers pour valider les dates
- `trg_check_date_publication_insert/update` : Empêche les dates de publication futures
- `trg_check_date_debut_insert/update` : Empêche les dates de collaboration futures

**Avantage** : Même garantie d'intégrité qu'un CHECK, conforme aux exigences de l'exercice.

#### Contraintes référentielles
- **Clés étrangères** : Relations avec CASCADE/RESTRICT
- **Métier** : Validation via triggers pour la somme des pourcentages

## 📋 Les 3 vues métier

### 1. `vue_administrateur`
**Usage** : Gestion quotidienne des données

**Colonnes clés** :
- Informations complètes du livre
- Détails de l'éditeur
- Liste concaténée des auteurs avec rôles
- Validation du statut des pourcentages

**Exemple** :
```sql
SELECT titre, nom_editeur, auteurs_details, statut_pourcentages 
FROM vue_administrateur 
WHERE statut_pourcentages LIKE '%vérifier%';
```

### 2. `vue_comptable`
**Usage** : Calcul des redevances mensuelles

**Colonnes clés** :
- Identification de l'auteur
- Pourcentage de redevance
- Calcul automatique de la redevance par livre vendu
- Statut de la collaboration

**Exemple** :
```sql
SELECT nom_complet_auteur, titre_livre, 
       redevance_par_livre_vendu, statut_collaboration
FROM vue_comptable 
WHERE statut_collaboration = 'Active'
ORDER BY redevance_par_livre_vendu DESC;
```

### 3. `vue_auteur`
**Usage** : Portail de consultation pour les auteurs

**Colonnes clés** :
- Mes participations et droits
- Mes redevances calculées
- Nombre de co-auteurs
- Durée de collaboration

**Exemple** :
```sql
SELECT titre, mon_role, mes_droits_pourcent, 
       ma_redevance_par_vente, statut
FROM vue_auteur 
WHERE id_auteur = 1
ORDER BY date_publication DESC;
```

## ✅ Tests de validation

Le fichier `tests.sql` contient **11 catégories de tests** :

1. ✓ Structure des tables, vues, index, triggers
2. ✓ Intégrité des données de base
3. ✓ Validation des contraintes de pourcentages
4. ✓ Validation des contraintes de dates
5. ✓ Validation des prix et quantités
6. ✓ Fonctionnement de la vue administrateur
7. ✓ Fonctionnement de la vue comptable
8. ✓ Fonctionnement de la vue auteur
9. ✓ Validation des triggers
10. ✓ Statistiques globales
11. ✓ Intégrité référentielle

**Exécution** :
```bash
sqlite3 database.db < tests.sql
```

## 🔧 Commandes utiles

### Backup de la base

```bash
# Backup complet
sqlite3 database.db ".backup backup_$(date +%Y%m%d).db"

# Export SQL
sqlite3 database.db .dump > backup.sql
```

### Restauration

```bash
# Depuis un backup
cp backup_20251205.db database.db

# Depuis un dump SQL
sqlite3 new_database.db < backup.sql
```

### Mode graphique (optionnel)

**DB Browser for SQLite** (gratuit)
- Télécharger : https://sqlitebrowser.org/
- Interface graphique pour explorer et éditer
- Visualisation des diagrammes ERD
- Export vers Excel, CSV, JSON

## 📈 Extensions possibles

1. **Ventes** : Ajouter une table pour tracer les ventes mensuelles
2. **Contrats** : Historiser les contrats d'édition
3. **Paiements** : Tracer les versements de redevances
4. **Analytics** : Dashboard avec statistiques avancées
5. **API REST** : Exposer les vues via une API (Python Flask/FastAPI)

## 🎓 Choix de modélisation justifiés

### SQLite vs PostgreSQL
- ✅ **SQLite choisi** : Léger, portable, parfait pour la démonstration
- ✅ Fichier unique versionnable (Git-friendly)
- ✅ Pas de serveur requis
- ✅ Syntaxe SQL standard compatible

### Normalisation 3FN
- Évite la redondance
- Facilite les mises à jour
- Respecte MERISE

### Triggers pour validation métier
- Validation automatique des pourcentages (somme = 100%)
- **Validation des dates** : Remplace les CHECK avec `DATE('now')` (limitation SQLite)
- Audit automatique (updated_at)

### Index stratégiques
- Optimisation des jointures (FK)
- Recherche rapide (nom, titre, ISBN)
- Performance des vues

## 📝 Notes techniques

- **Encodage** : UTF-8
- **Version SQLite** : 3.x minimum
- **PRAGMA foreign_keys** : Activé par défaut
- **AUTO_INCREMENT** : Utilise INTEGER PRIMARY KEY
- **Triggers** : BEFORE INSERT/UPDATE pour validation
- **Vues** : Matérialisées à la demande (pas de cache)

## 🆘 Dépannage

### Erreur "foreign key constraint failed"
```sql
-- Vérifier que PRAGMA est activé
PRAGMA foreign_keys;

-- Si retour 0, activer:
PRAGMA foreign_keys = ON;
```

### Réinitialiser la base
```bash
rm database.db
sqlite3 database.db < schema.sql
sqlite3 database.db < seed.sql
sqlite3 database.db < vues.sql
```

### Voir les erreurs SQL
```sql
-- Mode verbeux
.echo on
.read schema.sql
```

## 📞 Support

Pour toute question sur la modélisation ou l'implémentation SQL, consultez :
- **JUSTIFICATION_TECHNIQUE.md** : Explication détaillée des contraintes CHECK et TRIGGERS
- Documentation SQLite : https://www.sqlite.org/docs.html
- SQL Tutorial : https://www.w3schools.com/sql/
- MERISE : https://sql.sh/cours/merise

---

**Version** : 1.0  
**Date** : 2025-12-05  
**Auteur** : Solution Modélisation-1  
**Licence** : Educational Use
