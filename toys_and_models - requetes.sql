# choix de la base de données
USE toys_and_models ;
# choix de la langue dans les colonnes 'MONTHNAME'
SET lc_time_names = 'fr_FR';

/* ******************************************************************************************************************************************************************************** */
--	1. Dashboard Ventes (commandes)
/* ******************************************************************************************************************************************************************************** */
-- # Q_1_1
--	Nombre de produits vendus (commandés) par catégorie et par mois avec comparaison à lannée précédente
-- en gros ici on parle de quantité commandée et de nombre de ventes, pas d'argents, on compare avec les performances de l'année précédente et on donne les taux de variations
/*
WITH aggregated_data AS (
    SELECT 
        productLine AS categorie,
        EXTRACT(YEAR FROM orderDate) AS année,
        LPAD(EXTRACT(MONTH FROM orderDate), 2, '0') AS mois,
        MONTHNAME(orderDate) AS monthname,  -- Ajout du nom du mois
        SUM(quantityOrdered) AS `quantité commandée`, 
        COUNT(orderdetails.productCode) AS `nombre de ventes`
    FROM orders  
    JOIN orderdetails USING(orderNumber)
    JOIN products USING(productCode)
    GROUP BY productLine, année, mois, monthname  -- Inclure monthname dans le GROUP BY
)

SELECT  
    categorie,
    année,
    mois,
    monthname,  -- Ajout du nom du mois
    CONCAT(année, '/', mois) AS DateID,
    `quantité commandée`,
    `nombre de ventes`,
    LAG(`quantité commandée`) OVER (PARTITION BY categorie, mois ORDER BY année) AS `quantité commandée l'an dernier au même mois`,
    LAG(`nombre de ventes`) OVER (PARTITION BY categorie, mois ORDER BY année) AS `nombre de ventes l'an dernier au même mois`,
    round(((`quantité commandée` - LAG(`quantité commandée`) OVER (PARTITION BY categorie, mois ORDER BY année)) / NULLIF(LAG(`quantité commandée`) OVER (PARTITION BY categorie, mois ORDER BY année), 0) * 100),2) AS `taux de variation des commandes`,
    round(((`nombre de ventes` - LAG(`nombre de ventes`) OVER (PARTITION BY categorie, mois ORDER BY année)) / NULLIF(LAG(`nombre de ventes`) OVER (PARTITION BY categorie, mois ORDER BY année), 0) * 100),2) AS `taux de variation du nombre de ventes`
FROM aggregated_data;
*/

/* ******************************************************************************************************************************************************************************** */
# top 5 des produits les plus et moins commandés
# Q_1_2

/*
WITH RankedOrders AS (
    SELECT 
        p.productName AS `produit`,
        p.productLine AS `categorie`,
        EXTRACT(YEAR FROM o.orderDate) AS année,
        LPAD(EXTRACT(MONTH FROM o.orderDate), 2, '0') AS mois,
        MONTHNAME(o.orderDate) AS monthname,
        DATE_FORMAT(o.orderDate, '%Y/%m/%d') AS date,
        SUM(od.quantityOrdered) AS `quantité commandée`,
        ROW_NUMBER() OVER (PARTITION BY EXTRACT(YEAR FROM o.orderDate), LPAD(EXTRACT(MONTH FROM o.orderDate), 2, '0') ORDER BY SUM(od.quantityOrdered) DESC) AS rank_plus,
        ROW_NUMBER() OVER (PARTITION BY EXTRACT(YEAR FROM o.orderDate), LPAD(EXTRACT(MONTH FROM o.orderDate), 2, '0') ORDER BY SUM(od.quantityOrdered) ASC) AS rank_moins
    FROM products p
    JOIN orderdetails od USING(productCode)
    JOIN orders o ON od.orderNumber = o.orderNumber
    WHERE EXTRACT(YEAR FROM o.orderDate) IN (2022, 2023, 2024)
    GROUP BY p.productName, p.productLine, année, mois, monthname, date
)
SELECT 
    produit, 
    categorie, 
    année, 
    mois, 
    monthname, 
    date, 
    `quantité commandée`,
    `niveau de commande`
FROM (
    SELECT 
        produit,
        categorie,
        année,
        mois,
        monthname,
        date,
        `quantité commandée`,
        'Dans le top 5 des produits les plus commandés' AS `niveau de commande`
    FROM RankedOrders
    WHERE rank_plus <= 5

    UNION ALL

    SELECT 
        produit,
        categorie,
        année,
        mois,
        monthname,
        date,
        `quantité commandée`,
        'Dans le top 5 des produits les moins commandés' AS `niveau de commande`
    FROM RankedOrders
    WHERE rank_moins <= 5
) AS final
ORDER BY année DESC, mois DESC, `quantité commandée` DESC;
*/



/* ******************************************************************************************************************************************************************************** */
#	2. Dashboard Finances
/* ******************************************************************************************************************************************************************************** */
#	Chiffre d’affaires des commandes des deux derniers mois par pays
# Q_2_1
-- la requete ne limite pas les mois, l'utilisateur selectionnera le nombre de mois qu'il veut dans le selecteur de date
/*
SELECT 
    c.country AS pays,
    EXTRACT(YEAR FROM o.orderDate) AS année,
    LPAD(EXTRACT(MONTH FROM o.orderDate), 2, '0') AS mois,
    MONTHNAME(o.orderDate) AS `nom du mois`,
    CONCAT(EXTRACT(YEAR FROM o.orderDate), '/', LPAD(EXTRACT(MONTH FROM o.orderDate), 2, '0')) AS DateID,
    SUM(od.quantityOrdered * od.priceEach) AS `chiffre d'affaire`
FROM orders o
JOIN orderdetails od USING(orderNumber)
JOIN customers c USING(customerNumber)
GROUP BY c.country, année, mois, MONTHNAME(o.orderDate), DateID
ORDER BY c.country ASC, année DESC, mois DESC;
*/
/* ******************************************************************************************************************************************************************************** */
# balance des clients
# Q_2_2
# permets de savoir dans le detail ceux qui doivent et ceux à qui l'entreprise doit

-- Total des commandes par client avec prise en compte des statuts pertinents
/*
WITH total_orders AS (
    SELECT 
        c.customerNumber,
        c.customerName,
        SUM(od.quantityOrdered * od.priceEach) AS total_order_value
    FROM orders o
    JOIN orderdetails od ON o.orderNumber = od.orderNumber
    JOIN customers c ON o.customerNumber = c.customerNumber
    WHERE o.status IN ('Shipped', 'Resolved', 'On hold')  -- Exclure les commandes 'Cancelled'
    GROUP BY c.customerNumber, c.customerName
),

-- Total des paiements par client
total_payments AS (
    SELECT 
        customerNumber,
        SUM(amount) AS total_payment_value
    FROM payments
    GROUP BY customerNumber
)

-- Comparaison des montants de commandes et de paiements
SELECT * FROM (
    SELECT 
        o.customerNumber,
        o.customerName,
        o.total_order_value,
        COALESCE(p.total_payment_value, 0) AS total_payment_value,
        -(o.total_order_value - COALESCE(p.total_payment_value, 0)) AS `solde client`
    FROM total_orders o
    LEFT JOIN total_payments p ON o.customerNumber = p.customerNumber
) AS result
WHERE `solde client` <> 0
ORDER BY `solde client` ASC;
*/
/* ******************************************************************************************************************************************************************************** */
# la somme totale cumulée des commandes
# Q_2_3
/*
SELECT 
    SUM(total_order_value) AS total_order_value
FROM (
    SELECT 
        c.customerNumber,
        SUM(od.quantityOrdered * od.priceEach) AS total_order_value
    FROM orders o
    JOIN orderdetails od ON o.orderNumber = od.orderNumber
    JOIN customers c ON o.customerNumber = c.customerNumber
    WHERE o.status IN ('Shipped', 'Resolved', 'On hold')  -- Exclure les commandes 'Cancelled'
    GROUP BY c.customerNumber
) AS total_orders;
*/
/* ******************************************************************************************************************************************************************************** */
# la somme total cumulée des paiements
# Q_2_4
/*
SELECT 
    SUM(total_payment_value) AS total_payment_value
FROM (
    SELECT 
        customerNumber,
        SUM(amount) AS total_payment_value
    FROM payments
    GROUP BY customerNumber
) AS total_payments;
*/
/* ******************************************************************************************************************************************************************************** */
# la balance cumulée
# non pris en compte dans power BI car il y et deja dans Q_2_1
/*
SELECT 
    -1 * (
        (SELECT SUM(total_order_value)
         FROM (
             SELECT 
                 c.customerNumber,
                 SUM(od.quantityOrdered * od.priceEach) AS total_order_value
             FROM orders o
             JOIN orderdetails od ON o.orderNumber = od.orderNumber
             JOIN customers c ON o.customerNumber = c.customerNumber
             WHERE o.status IN ('Shipped', 'Resolved', 'On hold')  -- Exclure les commandes 'Cancelled'
             GROUP BY c.customerNumber
         ) AS total_orders
        ) - 
        (SELECT SUM(total_payment_value)
         FROM (
             SELECT 
                 customerNumber,
                 SUM(amount) AS total_payment_value
             FROM payments
             GROUP BY customerNumber
         ) AS total_payments
        )
    ) AS total_balance;
*/
/* ******************************************************************************************************************************************************************************** */
# chiffre d'affaire dans le temps
# non pris en compte dans power BI car il y et deja dans Q_2_1
/*
SELECT 
    EXTRACT(YEAR FROM orderDate) AS année,
    LPAD(EXTRACT(MONTH FROM orderDate), 2, '0') AS mois,
    MONTHNAME(orderDate) AS `nom du mois`,
    DATE_FORMAT(orderDate, '%Y/%m') AS `DateID`,
    ROUND(SUM(quantityOrdered * priceEach),2) AS `chiffre d'affaire`
FROM orders
JOIN orderdetails USING(orderNumber)
GROUP BY année, mois, `nom du mois`, `DateID`
ORDER BY année DESC, mois DESC;
*/
/* ******************************************************************************************************************************************************************************** */
# marge beneficiaire par produit
# Q_2_5
/*
SELECT 
    p.productLine AS categorie,
    p.productName AS `nom du produit`,
    EXTRACT(YEAR FROM o.orderDate) AS année,
    LPAD(EXTRACT(MONTH FROM orderDate), 2, '0') AS mois,
    MONTHNAME(orderDate) AS `nom du mois`,
    DATE_FORMAT(orderDate, '%Y/%m') AS `DateID`,
    p.buyPrice AS `prix d'achat`,
    od.priceEach AS `prix de vente`,
    od.quantityOrdered AS `quantité commandée`,
    (od.priceEach - p.buyPrice) * od.quantityOrdered AS `marge beneficiaire`
FROM products p
JOIN orderdetails od USING(productCode)
JOIN orders o ON od.orderNumber = o.orderNumber
GROUP BY categorie, `nom du produit`, année, mois, `nom du mois`, `DateID`, `prix d'achat`, `prix de vente`, `quantité commandée`
ORDER BY année DESC, mois DESC, `marge beneficiaire` DESC ;
*/
/* ******************************************************************************************************************************************************************************** */
# prix du panier_moyen
# Q_2_6
-- Calcul du prix du panier par commande
/*
WITH order_prices AS (
    SELECT 
        orderNumber,
        EXTRACT(YEAR FROM orderDate) AS année,
        LPAD(EXTRACT(MONTH FROM orderDate), 2, '0') AS mois,
        MONTHNAME(orderDate) AS `nom du mois`,
        DATE_FORMAT(orderDate, '%Y/%m') AS DateID,
        SUM(quantityOrdered * priceEach) AS `montant de la commande`
    FROM orders
    JOIN orderdetails USING(orderNumber)
    GROUP BY orderNumber, année, mois, `nom du mois`, DateID
),

-- Calcul du panier moyen par période
average_basket AS (
    SELECT 
        année,
        mois,
        `nom du mois`,
        DateID,
        AVG(`montant de la commande`) AS `panier moyen`  -- Correction : Utilisation de `montant de la commande` au lieu de `order_total`
    FROM order_prices
    GROUP BY année, mois, `nom du mois`, DateID
)

-- Comparaison des prix du panier avec le panier moyen
SELECT 
    o.orderNumber AS `numero de commande`,
    o.année AS `année`,
    o.mois AS `mois`,
    o.`nom du mois` AS `nom du mois`,
    o.DateID AS `DateID`,
    o.`montant de la commande` AS `montant de la commande`,
    a.`panier moyen` AS `panier moyen`,
    -1*(a.`panier moyen` - o.`montant de la commande`) AS difference,  -- Correction : Utilisation de `montant de la commande` au lieu de `order_total`
    round(-1*( (a.`panier moyen` - o.`montant de la commande`) / o.`montant de la commande` ) * 100,2) AS `pourcentage de variation`  -- Correction : Utilisation de `montant de la commande` au lieu de `order_total`
FROM order_prices o
JOIN average_basket a ON o.année = a.année AND o.mois = a.mois
ORDER BY o.année DESC, o.mois DESC, o.`montant de la commande` DESC;

*/
/* ******************************************************************************************************************************************************************************** */
 # Logistique : Le stock des 5 produits les plus commandés (avec en plus le stock turnover ratio)
/* ******************************************************************************************************************************************************************************** */
#Q_3_1
/*
SELECT 
    p.productName AS `nom de produit`,
    p.productLine AS `categorie`,
    EXTRACT(YEAR FROM o.orderDate) AS année,
    LPAD(EXTRACT(MONTH FROM o.orderDate), 2, '0') AS mois,
    MONTHNAME(o.orderDate) AS `nom du mois`,
    CONCAT(EXTRACT(YEAR FROM o.orderDate), '/', LPAD(EXTRACT(MONTH FROM o.orderDate), 2, '0')) AS DateID,
    p.quantityInStock,
    SUM(od.quantityOrdered) AS total_quantity_ordered,
    floor((p.quantityInStock / SUM(od.quantityOrdered))) AS `ratio de rotation des stocks`
FROM products p
JOIN orderdetails od USING(productCode)
JOIN orders o ON od.orderNumber = o.orderNumber
GROUP BY p.productName, p.productLine, année, mois, `nom du mois`, DateID, p.quantityInStock
ORDER BY année DESC, mois DESC, total_quantity_ordered DESC ;
*/



#temps moyen de traitement des commandes
#Q_3_2
/*
SELECT 
    orderNumber,
    EXTRACT(YEAR FROM orderDate) AS année,
    LPAD(EXTRACT(MONTH FROM orderDate), 2, '0') AS mois,
    LPAD(EXTRACT(DAY FROM orderDate), 2, '0') AS jour,
    CONCAT(EXTRACT(YEAR FROM orderDate), '/', LPAD(EXTRACT(MONTH FROM orderDate), 2, '0')) AS DateID_short,
    CONCAT(EXTRACT(YEAR FROM orderDate), '/', LPAD(EXTRACT(MONTH FROM orderDate), 2, '0'), '/', LPAD(EXTRACT(DAY FROM orderDate), 2, '0')) AS DateID_long,
    orderDate AS `date de commande`,
    shippedDate AS `date d'expedition`,
    DATEDIFF(shippedDate, orderDate) AS `temps de traitement de commande`,
    AVG(DATEDIFF(shippedDate, orderDate)) OVER (PARTITION BY EXTRACT(YEAR FROM orderDate), EXTRACT(MONTH FROM orderDate)) AS `temps_moyen_de traitement`
FROM orders
ORDER BY année DESC, mois DESC, jour DESC, DateID_short DESC, DateID_long DESC, `temps de traitement de commande` DESC;
*/


# taux de retour de produit et valeurs des produits retournés
#Q_3_3
/*
SELECT
    p.productLine AS `categorie`,
    p.productName AS `nom de produit`,
    SUM(od.quantityOrdered) AS `nombre de commandes`,
    COALESCE(SUM(CASE WHEN o.status = 'Cancelled' THEN od.quantityOrdered ELSE 0 END), 0) AS `nombre d'annulation`,
    ROUND((COALESCE(SUM(CASE WHEN o.status = 'Cancelled' THEN od.quantityOrdered ELSE 0 END), 0) / SUM(od.quantityOrdered)) * 100, 2) AS `taux d'annulation`,
    SUM(CASE WHEN o.status = 'Cancelled' THEN od.quantityOrdered * od.priceEach ELSE 0 END) AS `valeur des commandes annulées`
FROM products p
JOIN orderdetails od USING(productCode)
JOIN orders o USING(orderNumber)
GROUP BY p.productLine, p.productName
HAVING `taux d'annulation` <> 0
ORDER BY `taux d'annulation` DESC;
*/



/* ******************************************************************************************************************************************************************************** */
# Ressources humaines : Chaque mois, les 2 vendeurs ayant réalisé le plus de chiffre d’affaires.
/* ******************************************************************************************************************************************************************************** */
#Q_4_1
/*
WITH MonthlySales AS (
    SELECT
        c.salesRepEmployeeNumber AS `EMPLOYEE_ID`,
        CONCAT(e.firstName, ' ', e.lastName) AS `SALESPERSON`, -- Nom du vendeur
        DATE_FORMAT(o.orderDate, '%Y-%m') AS `SALE_MONTH`, -- Mois de la vente
        YEAR(o.orderDate) AS `yyyy`, -- Année
        DATE_FORMAT(o.orderDate, '%m') AS `mm`, -- Mois en format 'mm'
        DATE_FORMAT(o.orderDate, '%Y/%m') AS `DateID`, -- DateID
        SUM(od.quantityOrdered * od.priceEach) AS `TOTAL_SALES`, -- Somme des ventes
        off.country AS `Country`, -- Pays de l'employé
        off.city AS `City`, -- Ville de l'employé
        e.officeCode AS `OfficeCode` -- Code office de l'employé
    FROM
        employees e
    INNER JOIN customers c ON e.employeeNumber = c.salesRepEmployeeNumber
    INNER JOIN orders o ON c.customerNumber = o.customerNumber
    INNER JOIN orderdetails od ON o.orderNumber = od.orderNumber
    INNER JOIN offices off ON off.officeCode = e.officeCode
    GROUP BY
        `SALESPERSON`, `SALE_MONTH`, c.salesRepEmployeeNumber, `yyyy`, `mm`, `DateID`, off.country, off.city, e.officeCode
)
SELECT
    `SALE_MONTH`,
    `SALESPERSON`,
    `EMPLOYEE_ID`,
    `TOTAL_SALES`,
    `yyyy`,
    `mm`,
    `DateID`,
    `Country`,
    `City`,
    `OfficeCode`
FROM (
    SELECT
        `SALE_MONTH`,
        `SALESPERSON`,
        `EMPLOYEE_ID`,
        `TOTAL_SALES`,
        `yyyy`,
        `mm`,
        `DateID`,
        `Country`,
        `City`,
        `OfficeCode`,
        ROW_NUMBER() OVER (PARTITION BY `SALE_MONTH` ORDER BY `TOTAL_SALES` DESC) AS sales_rank
    FROM
        MonthlySales
) AS ranked_sales
WHERE
    sales_rank <= 3 -- Top 3 au lieu de top 2
ORDER BY
    `yyyy` DESC, -- Trie par année (2024 en premier)
    `SALE_MONTH` DESC, -- Trie par mois
    `TOTAL_SALES` DESC; -- Trie par chiffre d'affaires décroissant
*/






# nombre de commandes par employees
# RH
-- code luna
/*
SELECT 
    off.officeCode, 
    off.country, 
    off.city,
    COUNT(DISTINCT e.employeeNumber) AS nb_employees,
    COUNT(o.orderNumber) AS nb_commandes,
    FLOOR(COUNT(o.orderNumber) / COUNT(DISTINCT e.employeeNumber)) AS nb_cde_per_employe
FROM offices off
LEFT JOIN employees e ON e.officeCode = off.officeCode
LEFT JOIN customers c ON c.salesRepEmployeeNumber = e.employeeNumber
LEFT JOIN orders o ON c.customerNumber = o.customerNumber
GROUP BY off.officeCode, off.country, off.city
ORDER BY nb_cde_per_employe DESC;
*/


-- code luna modifié
/*
WITH EmployeeCount AS (
    SELECT 
        officeCode, 
        COUNT(employeeNumber) AS nb_employees
    FROM employees
    GROUP BY officeCode
),
OrderCount AS (
    SELECT
        off.officeCode,
        off.country,
        off.city,
        COUNT(o.orderNumber) AS nb_commandes,
        YEAR(o.orderDate) AS `yyyy`,
        DATE_FORMAT(o.orderDate, '%m') AS `mm`,
        DATE_FORMAT(o.orderDate, '%Y/%m') AS `DateID`
    FROM offices off
    LEFT JOIN employees e ON e.officeCode = off.officeCode
    LEFT JOIN customers c ON c.salesRepEmployeeNumber = e.employeeNumber
    LEFT JOIN orders o ON c.customerNumber = o.customerNumber
    WHERE o.orderDate >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) -- Filtre sur les 12 derniers mois
    GROUP BY off.officeCode, off.country, off.city, `yyyy`, `mm`, `DateID`
)
SELECT 
    oc.officeCode, 
    oc.country, 
    oc.city,
    ec.nb_employees,
    oc.nb_commandes,
    FLOOR(oc.nb_commandes / ec.nb_employees) AS nb_cde_per_employe,
    oc.`yyyy`,
    oc.`mm`,
    oc.`DateID`
FROM OrderCount oc
LEFT JOIN EmployeeCount ec ON oc.officeCode = ec.officeCode
ORDER BY nb_cde_per_employe DESC;
*/

/*
SELECT 
    COUNT(o.orderNumber) AS nb_commandes
FROM offices off
LEFT JOIN employees e ON e.officeCode = off.officeCode
LEFT JOIN customers c ON c.salesRepEmployeeNumber = e.employeeNumber
LEFT JOIN orders o ON c.customerNumber = o.customerNumber
WHERE off.city = 'Paris'
  AND MONTH(o.orderDate) = 12
  AND YEAR(o.orderDate) = 2023;
*/


WITH EmployeeCount AS (
    SELECT 
        officeCode, 
        COUNT(employeeNumber) AS nb_employees
    FROM employees
    GROUP BY officeCode
),
OrderCount AS (
    SELECT
        off.officeCode,
        off.country,
        off.city,
        e.employeeNumber AS `EMPLOYEE_ID`,
        CONCAT(e.firstName, ' ', e.lastName) AS `EMPLOYEE_NAME`,
        COUNT(o.orderNumber) AS nb_commandes,
        YEAR(o.orderDate) AS `yyyy`,
        DATE_FORMAT(o.orderDate, '%m') AS `mm`,
        DATE_FORMAT(o.orderDate, '%Y/%m') AS `DateID`
    FROM offices off
    LEFT JOIN employees e ON e.officeCode = off.officeCode
    LEFT JOIN customers c ON c.salesRepEmployeeNumber = e.employeeNumber
    LEFT JOIN orders o ON c.customerNumber = o.customerNumber
    WHERE o.orderDate >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) -- Filtre sur les 12 derniers mois
    GROUP BY off.officeCode, off.country, off.city, e.employeeNumber, `yyyy`, `mm`, `DateID`
)
SELECT 
    oc.officeCode, 
    oc.country, 
    oc.city,
    oc.`EMPLOYEE_ID`,
    oc.`EMPLOYEE_NAME`,
    oc.nb_commandes,
    ec.nb_employees,
    FLOOR(oc.nb_commandes / ec.nb_employees) AS nb_cde_per_employe,
    oc.`yyyy`,
    oc.`mm`,
    oc.`DateID`
FROM OrderCount oc
LEFT JOIN EmployeeCount ec ON oc.officeCode = ec.officeCode
ORDER BY oc.`yyyy` DESC, oc.`mm` DESC, oc.nb_commandes DESC;
