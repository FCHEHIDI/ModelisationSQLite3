-- ============================================================================
-- VUES SQL - SYSTÈME DE REDEVANCES D'ÉDITION
-- ============================================================================
-- Ce fichier définit les 3 vues demandées dans le contexte métier
-- ============================================================================

-- ============================================================================
-- VUE 1: VUE ADMINISTRATEUR
-- Description: Vue complète pour gérer auteurs, livres et éditeurs
-- Usage: Gestion quotidienne des données par l'équipe administrative
-- ============================================================================

CREATE VIEW IF NOT EXISTS vue_administrateur AS
SELECT 
    -- Informations du livre
    l.id_livre,
    l.isbn,
    l.titre,
    l.genre,
    l.date_publication,
    l.prix_vente,
    l.nombre_pages,
    
    -- Informations de l'éditeur
    e.id_editeur,
    e.nom_editeur,
    e.telephone as telephone_editeur,
    e.email as email_editeur,
    
    -- Informations des auteurs (concaténées)
    GROUP_CONCAT(
        a.prenom || ' ' || a.nom || ' (' || p.role || ' - ' || p.pourcentage_redevance || '%)',
        '; '
    ) as auteurs_details,
    
    -- Nombre d'auteurs participant au livre
    COUNT(DISTINCT a.id_auteur) as nombre_auteurs,
    
    -- Somme des pourcentages (doit être 100)
    SUM(p.pourcentage_redevance) as total_pourcentage,
    
    -- Statut de validation
    CASE 
        WHEN SUM(p.pourcentage_redevance) = 100 THEN '✓ Validé'
        ELSE '⚠ À vérifier'
    END as statut_pourcentages,
    
    -- Dates de modification
    l.created_at as date_creation_livre,
    l.updated_at as date_maj_livre
    
FROM LIVRE l
INNER JOIN EDITEUR e ON l.id_editeur = e.id_editeur
LEFT JOIN PARTICIPATION p ON l.id_livre = p.id_livre
LEFT JOIN AUTEUR a ON p.id_auteur = a.id_auteur
GROUP BY l.id_livre, l.isbn, l.titre, l.genre, l.date_publication, 
         l.prix_vente, l.nombre_pages, e.id_editeur, e.nom_editeur,
         e.telephone, e.email, l.created_at, l.updated_at
ORDER BY l.date_publication DESC, l.titre;

-- ============================================================================
-- VUE 2: VUE COMPTABLE
-- Description: Calcul des redevances mensuelles par auteur
-- Usage: Génération des bulletins de paiement et calcul des droits
-- ============================================================================

CREATE VIEW IF NOT EXISTS vue_comptable AS
SELECT 
    -- Identification de l'auteur
    a.id_auteur,
    a.prenom || ' ' || a.nom as nom_complet_auteur,
    a.email as email_auteur,
    a.telephone as telephone_auteur,
    
    -- Informations du livre
    l.id_livre,
    l.titre as titre_livre,
    l.isbn,
    l.prix_vente,
    
    -- Informations de participation
    p.pourcentage_redevance,
    p.role,
    p.date_debut as date_debut_collaboration,
    p.date_fin as date_fin_collaboration,
    
    -- Calcul des redevances (base: 10% du prix de vente réparti selon pourcentage)
    ROUND(l.prix_vente * 0.10 * (p.pourcentage_redevance / 100.0), 2) as redevance_par_livre_vendu,
    
    -- Éditeur
    e.nom_editeur,
    
    -- Statut de la collaboration
    CASE 
        WHEN p.date_fin IS NULL THEN 'Active'
        WHEN p.date_fin >= DATE('now') THEN 'Active'
        ELSE 'Terminée'
    END as statut_collaboration,
    
    -- Calcul du nombre de jours de collaboration
    CASE 
        WHEN p.date_fin IS NULL THEN 
            JULIANDAY('now') - JULIANDAY(p.date_debut)
        ELSE 
            JULIANDAY(p.date_fin) - JULIANDAY(p.date_debut)
    END as jours_collaboration,
    
    -- Information pour simulation de ventes
    l.genre as genre_livre,
    l.date_publication
    
FROM PARTICIPATION p
INNER JOIN AUTEUR a ON p.id_auteur = a.id_auteur
INNER JOIN LIVRE l ON p.id_livre = l.id_livre
INNER JOIN EDITEUR e ON l.id_editeur = e.id_editeur
WHERE p.date_debut <= DATE('now')
ORDER BY a.nom, a.prenom, l.date_publication DESC;

-- ============================================================================
-- VUE 3: VUE AUTEUR
-- Description: Vue personnalisée pour consultation par les auteurs
-- Usage: Portail auteur - consultation des participations et droits
-- ============================================================================

CREATE VIEW IF NOT EXISTS vue_auteur AS
SELECT 
    -- Identification de l'auteur (pour filtrage ultérieur)
    a.id_auteur,
    a.prenom || ' ' || a.nom as nom_auteur,
    
    -- Informations du livre
    l.titre,
    l.isbn,
    l.genre,
    l.date_publication,
    l.nombre_pages,
    l.prix_vente,
    
    -- Informations de l'éditeur
    e.nom_editeur,
    e.email as contact_editeur,
    
    -- Détails de participation
    p.role as mon_role,
    p.pourcentage_redevance as mes_droits_pourcent,
    
    -- Calcul de mes redevances
    ROUND(l.prix_vente * 0.10 * (p.pourcentage_redevance / 100.0), 2) as ma_redevance_par_vente,
    
    -- Dates importantes
    p.date_debut as debut_collaboration,
    p.date_fin as fin_collaboration,
    
    -- Statut
    CASE 
        WHEN p.date_fin IS NULL THEN 'En cours'
        WHEN p.date_fin >= DATE('now') THEN 'En cours'
        ELSE 'Terminée le ' || p.date_fin
    END as statut,
    
    -- Co-auteurs (si applicable)
    (
        SELECT COUNT(*) - 1 
        FROM PARTICIPATION p2 
        WHERE p2.id_livre = l.id_livre
    ) as nombre_coauteurs,
    
    -- Ancienneté de la collaboration
    CASE 
        WHEN p.date_fin IS NULL THEN 
            CAST((JULIANDAY('now') - JULIANDAY(p.date_debut)) / 365.25 AS INTEGER) || ' ans'
        ELSE 
            CAST((JULIANDAY(p.date_fin) - JULIANDAY(p.date_debut)) / 365.25 AS INTEGER) || ' ans'
    END as duree_collaboration,
    
    -- Indicateurs de performance du livre
    ROUND(JULIANDAY('now') - JULIANDAY(l.date_publication), 0) as jours_depuis_publication,
    
    CASE 
        WHEN JULIANDAY('now') - JULIANDAY(l.date_publication) < 365 THEN '🆕 Nouveauté'
        WHEN JULIANDAY('now') - JULIANDAY(l.date_publication) < 1095 THEN '📚 Récent'
        ELSE '📖 Catalogue'
    END as categorie_age
    
FROM PARTICIPATION p
INNER JOIN AUTEUR a ON p.id_auteur = a.id_auteur
INNER JOIN LIVRE l ON p.id_livre = l.id_livre
INNER JOIN EDITEUR e ON l.id_editeur = e.id_editeur
ORDER BY a.id_auteur, l.date_publication DESC;

-- ============================================================================
-- VUES AUXILIAIRES - STATISTIQUES GÉNÉRALES
-- ============================================================================

-- Vue pour les statistiques globales
CREATE VIEW IF NOT EXISTS vue_statistiques_globales AS
SELECT 
    (SELECT COUNT(*) FROM AUTEUR) as total_auteurs,
    (SELECT COUNT(*) FROM EDITEUR) as total_editeurs,
    (SELECT COUNT(*) FROM LIVRE) as total_livres,
    (SELECT COUNT(*) FROM PARTICIPATION) as total_participations,
    (SELECT ROUND(AVG(prix_vente), 2) FROM LIVRE) as prix_moyen_livre,
    (SELECT ROUND(AVG(nombre_pages), 0) FROM LIVRE) as pages_moyennes,
    (SELECT COUNT(DISTINCT genre) FROM LIVRE) as nombre_genres;

-- Vue pour les livres avec problèmes de pourcentage
CREATE VIEW IF NOT EXISTS vue_livres_pourcentage_invalide AS
SELECT 
    l.id_livre,
    l.titre,
    l.isbn,
    e.nom_editeur,
    COALESCE(SUM(p.pourcentage_redevance), 0) as total_pourcentage,
    100 - COALESCE(SUM(p.pourcentage_redevance), 0) as ecart
FROM LIVRE l
INNER JOIN EDITEUR e ON l.id_editeur = e.id_editeur
LEFT JOIN PARTICIPATION p ON l.id_livre = p.id_livre
GROUP BY l.id_livre, l.titre, l.isbn, e.nom_editeur
HAVING total_pourcentage != 100
ORDER BY ABS(ecart) DESC;

-- ============================================================================
-- VÉRIFICATION DES VUES CRÉÉES
-- ============================================================================

SELECT '✓ Vues créées avec succès!' as message;
SELECT name as vue_name FROM sqlite_master 
WHERE type='view' 
ORDER BY name;
