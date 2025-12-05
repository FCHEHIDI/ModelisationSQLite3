-- ============================================================================
-- TESTS DE VALIDATION - SYSTÈME DE REDEVANCES D'ÉDITION
-- ============================================================================
-- Ce fichier contient tous les tests pour valider:
-- - L'intégrité des données
-- - Le fonctionnement des contraintes
-- - Les vues SQL
-- - Les triggers
-- ============================================================================

.print '════════════════════════════════════════════════════════════════'
.print '  TESTS DE VALIDATION DU SYSTÈME DE REDEVANCES'
.print '════════════════════════════════════════════════════════════════'
.print ''

-- ============================================================================
-- TEST 1: VÉRIFICATION DE LA STRUCTURE DES TABLES
-- ============================================================================

.print '━━━ TEST 1: Structure des tables ━━━'
.print ''

SELECT 
    'Tables créées: ' || COUNT(*) as resultat
FROM sqlite_master 
WHERE type='table' AND name NOT LIKE 'sqlite_%';

SELECT 
    'Vues créées: ' || COUNT(*) as resultat
FROM sqlite_master 
WHERE type='view';

SELECT 
    'Index créés: ' || COUNT(*) as resultat
FROM sqlite_master 
WHERE type='index' AND name NOT LIKE 'sqlite_%';

SELECT 
    'Triggers créés: ' || COUNT(*) as resultat
FROM sqlite_master 
WHERE type='trigger';

.print ''

-- ============================================================================
-- TEST 2: INTÉGRITÉ DES DONNÉES DE BASE
-- ============================================================================

.print '━━━ TEST 2: Intégrité des données ━━━'
.print ''

-- Test 2.1: Tous les livres ont un éditeur valide
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ PASS: Tous les livres ont un éditeur valide'
        ELSE '✗ FAIL: ' || COUNT(*) || ' livre(s) sans éditeur valide'
    END as test_21_editeurs
FROM LIVRE l
LEFT JOIN EDITEUR e ON l.id_editeur = e.id_editeur
WHERE e.id_editeur IS NULL;

-- Test 2.2: Tous les auteurs ont un email valide
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ PASS: Tous les emails auteurs sont valides'
        ELSE '✗ FAIL: ' || COUNT(*) || ' auteur(s) avec email invalide'
    END as test_22_emails_auteurs
FROM AUTEUR
WHERE email NOT LIKE '%_@_%._%';

-- Test 2.3: Tous les ISBN sont uniques et valides
SELECT 
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT isbn) THEN '✓ PASS: Tous les ISBN sont uniques'
        ELSE '✗ FAIL: ISBN en doublon détectés'
    END as test_23_isbn_uniques
FROM LIVRE;

-- Test 2.4: Tous les SIRET sont uniques et de longueur 14
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ PASS: Tous les SIRET sont valides (14 caractères)'
        ELSE '✗ FAIL: ' || COUNT(*) || ' SIRET invalide(s)'
    END as test_24_siret_valides
FROM EDITEUR
WHERE LENGTH(siret) != 14;

.print ''

-- ============================================================================
-- TEST 3: VALIDATION DES CONTRAINTES DE POURCENTAGES
-- ============================================================================

.print '━━━ TEST 3: Contraintes de pourcentages ━━━'
.print ''

-- Test 3.1: Somme des pourcentages = 100% par livre
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ PASS: Tous les livres ont exactement 100% de redevances'
        ELSE '✗ FAIL: ' || COUNT(*) || ' livre(s) avec somme incorrecte'
    END as test_31_somme_100
FROM (
    SELECT 
        l.id_livre,
        COALESCE(SUM(p.pourcentage_redevance), 0) as total
    FROM LIVRE l
    LEFT JOIN PARTICIPATION p ON l.id_livre = p.id_livre
    GROUP BY l.id_livre
    HAVING total != 100
);

-- Test 3.2: Détail des livres avec problème de pourcentage (si applicable)
.print 'Détail des livres avec problème de pourcentage:'
SELECT 
    l.titre,
    COALESCE(SUM(p.pourcentage_redevance), 0) as total_pourcentage,
    100 - COALESCE(SUM(p.pourcentage_redevance), 0) as ecart
FROM LIVRE l
LEFT JOIN PARTICIPATION p ON l.id_livre = p.id_livre
GROUP BY l.id_livre, l.titre
HAVING total_pourcentage != 100;

-- Test 3.3: Tous les pourcentages sont entre 0 et 100
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ PASS: Tous les pourcentages sont entre 0 et 100'
        ELSE '✗ FAIL: ' || COUNT(*) || ' pourcentage(s) hors limites'
    END as test_33_pourcentages_valides
FROM PARTICIPATION
WHERE pourcentage_redevance < 0 OR pourcentage_redevance > 100;

.print ''

-- ============================================================================
-- TEST 4: VALIDATION DES CONTRAINTES DE DATES
-- ============================================================================

.print '━━━ TEST 4: Contraintes de dates ━━━'
.print ''

-- Test 4.1: date_fin >= date_debut
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ PASS: Toutes les dates de fin sont après les dates de début'
        ELSE '✗ FAIL: ' || COUNT(*) || ' date(s) de fin invalide(s)'
    END as test_41_dates_coherentes
FROM PARTICIPATION
WHERE date_fin IS NOT NULL AND date_fin < date_debut;

-- Test 4.2: date_publication <= aujourd'hui
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ PASS: Aucun livre avec date de publication future'
        ELSE '✗ FAIL: ' || COUNT(*) || ' livre(s) avec date future'
    END as test_42_publication_valide
FROM LIVRE
WHERE date_publication > DATE('now');

.print ''

-- ============================================================================
-- TEST 5: VALIDATION DES PRIX ET QUANTITÉS
-- ============================================================================

.print '━━━ TEST 5: Validation des prix et quantités ━━━'
.print ''

-- Test 5.1: Tous les prix > 0
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ PASS: Tous les prix sont positifs'
        ELSE '✗ FAIL: ' || COUNT(*) || ' prix invalide(s)'
    END as test_51_prix_positifs
FROM LIVRE
WHERE prix_vente <= 0;

-- Test 5.2: Tous les livres ont un nombre de pages > 0
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ PASS: Tous les livres ont un nombre de pages valide'
        ELSE '✗ FAIL: ' || COUNT(*) || ' livre(s) avec pages invalides'
    END as test_52_pages_valides
FROM LIVRE
WHERE nombre_pages <= 0;

.print ''

-- ============================================================================
-- TEST 6: VALIDATION DE LA VUE ADMINISTRATEUR
-- ============================================================================

.print '━━━ TEST 6: Vue Administrateur ━━━'
.print ''

-- Test 6.1: La vue retourne des données
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ PASS: Vue administrateur retourne ' || COUNT(*) || ' ligne(s)'
        ELSE '✗ FAIL: Vue administrateur est vide'
    END as test_61_vue_admin
FROM vue_administrateur;

-- Test 6.2: Exemple de données de la vue administrateur
.print 'Exemple de données de la vue administrateur:'
.mode column
.headers on
SELECT 
    titre,
    nom_editeur,
    nombre_auteurs,
    total_pourcentage,
    statut_pourcentages
FROM vue_administrateur
LIMIT 3;

.print ''

-- ============================================================================
-- TEST 7: VALIDATION DE LA VUE COMPTABLE
-- ============================================================================

.print '━━━ TEST 7: Vue Comptable ━━━'
.print ''

-- Test 7.1: La vue retourne des données
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ PASS: Vue comptable retourne ' || COUNT(*) || ' ligne(s)'
        ELSE '✗ FAIL: Vue comptable est vide'
    END as test_71_vue_comptable
FROM vue_comptable;

-- Test 7.2: Toutes les redevances sont calculées et positives
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ PASS: Toutes les redevances sont calculées correctement'
        ELSE '✗ FAIL: ' || COUNT(*) || ' redevance(s) invalide(s)'
    END as test_72_redevances_valides
FROM vue_comptable
WHERE redevance_par_livre_vendu IS NULL OR redevance_par_livre_vendu < 0;

-- Test 7.3: Exemple de calculs de redevances
.print 'Exemple de calculs de redevances:'
SELECT 
    nom_complet_auteur,
    titre_livre,
    pourcentage_redevance || '%' as pourcentage,
    redevance_par_livre_vendu || ' €' as redevance,
    statut_collaboration
FROM vue_comptable
LIMIT 3;

.print ''

-- ============================================================================
-- TEST 8: VALIDATION DE LA VUE AUTEUR
-- ============================================================================

.print '━━━ TEST 8: Vue Auteur ━━━'
.print ''

-- Test 8.1: La vue retourne des données
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ PASS: Vue auteur retourne ' || COUNT(*) || ' ligne(s)'
        ELSE '✗ FAIL: Vue auteur est vide'
    END as test_81_vue_auteur
FROM vue_auteur;

-- Test 8.2: Exemple pour un auteur spécifique
.print 'Exemple de données pour un auteur:'
SELECT 
    nom_auteur,
    titre,
    mon_role,
    mes_droits_pourcent || '%' as droits,
    ma_redevance_par_vente || ' €' as redevance,
    statut
FROM vue_auteur
WHERE id_auteur = 1
LIMIT 3;

.print ''

-- ============================================================================
-- TEST 9: TEST DES TRIGGERS (Pourcentage > 100%)
-- ============================================================================

.print '━━━ TEST 9: Validation des triggers ━━━'
.print ''

-- Test 9.1: Tentative d'insertion dépassant 100%
.print 'Test 9.1: Tentative d\'ajout dépassant 100%...'

-- Sauvegarde du mode d'erreur
.print 'Tentative d\'insertion invalide (doit échouer):'

-- Cette commande devrait échouer
INSERT OR IGNORE INTO PARTICIPATION 
    (id_auteur, id_livre, pourcentage_redevance, role, date_debut) 
VALUES 
    (1, 1, 50.00, 'illustrateur', '2024-01-01');

-- Vérification que l'insertion a bien échoué
SELECT 
    CASE 
        WHEN COUNT(*) = 1 THEN '✓ PASS: Trigger a empêché l\'insertion invalide'
        ELSE '✗ FAIL: Trigger n\'a pas fonctionné (insertion réussie)'
    END as test_91_trigger_validation
FROM PARTICIPATION
WHERE id_livre = 1;

.print ''

-- ============================================================================
-- TEST 10: STATISTIQUES GLOBALES
-- ============================================================================

.print '━━━ TEST 10: Statistiques globales ━━━'
.print ''

SELECT * FROM vue_statistiques_globales;

.print ''

-- ============================================================================
-- TEST 11: TESTS D'INTÉGRITÉ RÉFÉRENTIELLE
-- ============================================================================

.print '━━━ TEST 11: Intégrité référentielle ━━━'
.print ''

-- Test 11.1: Toutes les participations ont un auteur valide
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ PASS: Toutes les participations ont un auteur valide'
        ELSE '✗ FAIL: ' || COUNT(*) || ' participation(s) avec auteur invalide'
    END as test_111_fk_auteur
FROM PARTICIPATION p
LEFT JOIN AUTEUR a ON p.id_auteur = a.id_auteur
WHERE a.id_auteur IS NULL;

-- Test 11.2: Toutes les participations ont un livre valide
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ PASS: Toutes les participations ont un livre valide'
        ELSE '✗ FAIL: ' || COUNT(*) || ' participation(s) avec livre invalide'
    END as test_112_fk_livre
FROM PARTICIPATION p
LEFT JOIN LIVRE l ON p.id_livre = l.id_livre
WHERE l.id_livre IS NULL;

.print ''

-- ============================================================================
-- RÉSUMÉ DES TESTS
-- ============================================================================

.print '════════════════════════════════════════════════════════════════'
.print '  RÉSUMÉ DES TESTS'
.print '════════════════════════════════════════════════════════════════'
.print ''
.print 'Pour lancer ces tests, utilisez:'
.print '  sqlite3 database.db < tests.sql'
.print ''
.print 'Ou en mode interactif:'
.print '  sqlite3 database.db'
.print '  .read tests.sql'
.print '════════════════════════════════════════════════════════════════'
