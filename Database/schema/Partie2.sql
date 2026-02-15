-- Analyse des ventes par produit avec fonctions fenêtre
SELECT 
    p.productCode,
    p.productName,
    SUM(od.quantityOrdered * od.priceEach) AS total_sales,
    
    -- Rang par chiffre d'affaires
    RANK() OVER (ORDER BY SUM(od.quantityOrdered * od.priceEach) DESC) AS sales_rank,
    
    -- Pourcentage du total
    ROUND(
        SUM(od.quantityOrdered * od.priceEach) 
        / SUM(SUM(od.quantityOrdered * od.priceEach)) OVER () * 100,
        2
    ) AS percentage_of_total
    
FROM products p
JOIN orderdetails od ON p.productCode = od.productCode
GROUP BY p.productCode, p.productName
ORDER BY total_sales DESC;

SELECT 
    DATE_FORMAT(o.orderDate, '%Y-%m') AS month,
    SUM(od.quantityOrdered * od.priceEach) AS monthly_sales,

    -- Moyenne mobile sur 3 mois
    ROUND(
        AVG(SUM(od.quantityOrdered * od.priceEach)) 
        OVER (ORDER BY DATE_FORMAT(o.orderDate, '%Y-%m') 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
        2
    ) AS moving_avg_3_months

FROM orders o
JOIN orderdetails od ON o.orderNumber = od.orderNumber
GROUP BY month
ORDER BY month;
# afficher la hiérarchie employés → manager #
WITH RECURSIVE employee_hierarchy AS (
    
    -- Niveau 1 : Top managers (sans manager)
    SELECT 
        employeeNumber,
        firstName,
        lastName,
        reportsTo,
        1 AS level
    FROM employees
    WHERE reportsTo IS NULL

    UNION ALL

    -- Niveaux suivants
    SELECT 
        e.employeeNumber,
        e.firstName,
        e.lastName,
        e.reportsTo,
        eh.level + 1
    FROM employees e
    JOIN employee_hierarchy eh 
        ON e.reportsTo = eh.employeeNumber
)

SELECT *
FROM employee_hierarchy
ORDER BY level, employeeNumber;

# Segmentation clients VIP #
WITH customer_revenue AS (
    SELECT 
        c.customerNumber,
        c.customerName,
        SUM(od.quantityOrdered * od.priceEach) AS total_revenue,
        COUNT(DISTINCT o.orderNumber) AS total_orders,
        COUNT(DISTINCT p.productLine) AS product_lines_bought
    FROM customers c
    JOIN orders o ON c.customerNumber = o.customerNumber
    JOIN orderdetails od ON o.orderNumber = od.orderNumber
    JOIN products p ON od.productCode = p.productCode
    GROUP BY c.customerNumber, c.customerName
)

SELECT *,
       CASE 
           WHEN total_revenue > (SELECT AVG(total_revenue) FROM customer_revenue)
           THEN 'VIP'
           ELSE 'Standard'
       END AS segment
FROM customer_revenue
ORDER BY total_revenue DESC;

# Analyse temporelle avec SOUS-REQUÊTES CORRÉLÉES #
SELECT 
    YEAR(o.orderDate) AS year,
    COUNT(DISTINCT o.customerNumber) AS new_customers
FROM orders o
WHERE o.orderDate = (
    SELECT MIN(o2.orderDate)
    FROM orders o2
    WHERE o2.customerNumber = o.customerNumber
)
GROUP BY year
ORDER BY year;

SELECT 
    c.customerNumber,
    c.customerName,
    COUNT(o.orderNumber) AS total_orders,
    (
        SELECT COUNT(*)
        FROM orders o2
        WHERE o2.customerNumber = c.customerNumber
          AND o2.orderDate > DATE_SUB(MAX(o.orderDate), INTERVAL 1 YEAR)
    ) AS orders_last_year
FROM customers c
JOIN orders o ON c.customerNumber = o.customerNumber
GROUP BY c.customerNumber, c.customerName
HAVING total_orders > 1
ORDER BY total_orders DESC;

SELECT 
    p.productLine,
    
    SUM(CASE WHEN QUARTER(o.orderDate) = 1 THEN od.quantityOrdered * od.priceEach ELSE 0 END) AS Q1,
    SUM(CASE WHEN QUARTER(o.orderDate) = 2 THEN od.quantityOrdered * od.priceEach ELSE 0 END) AS Q2,
    SUM(CASE WHEN QUARTER(o.orderDate) = 3 THEN od.quantityOrdered * od.priceEach ELSE 0 END) AS Q3,
    SUM(CASE WHEN QUARTER(o.orderDate) = 4 THEN od.quantityOrdered * od.priceEach ELSE 0 END) AS Q4

FROM products p
JOIN orderdetails od ON p.productCode = od.productCode
JOIN orders o ON od.orderNumber = o.orderNumber
GROUP BY p.productLine
ORDER BY p.productLine;

# Calcul commission employé #
DELIMITER //

CREATE PROCEDURE calculate_employee_commission(IN emp_id INT)
BEGIN
    SELECT 
        e.employeeNumber,
        e.firstName,
        e.lastName,
        SUM(od.quantityOrdered * od.priceEach) AS total_sales,
        SUM(od.quantityOrdered * od.priceEach) * 0.05 AS commission
    FROM employees e
    JOIN customers c ON e.employeeNumber = c.salesRepEmployeeNumber
    JOIN orders o ON c.customerNumber = o.customerNumber
    JOIN orderdetails od ON o.orderNumber = od.orderNumber
    WHERE e.employeeNumber = emp_id
    GROUP BY e.employeeNumber;
END //

DELIMITER ;

# gestion stock #
DELIMITER //

CREATE PROCEDURE update_stock(
    IN prod_code VARCHAR(15),
    IN quantity INT
)
BEGIN
    UPDATE products
    SET quantityInStock = quantityInStock - quantity
    WHERE productCode = prod_code;
END //

DELIMITER ;

# fonction #
DELIMITER //

CREATE FUNCTION customer_lifetime_value(cust_id INT)
RETURNS DECIMAL(15,2)
DETERMINISTIC
BEGIN
    DECLARE total DECIMAL(15,2);

    SELECT SUM(od.quantityOrdered * od.priceEach)
    INTO total
    FROM orders o
    JOIN orderdetails od ON o.orderNumber = od.orderNumber
    WHERE o.customerNumber = cust_id;

    RETURN IFNULL(total, 0);
END //

DELIMITER ;

# TRIGGERS #
CREATE TABLE orders_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    orderNumber INT,
    action_type VARCHAR(50),
    action_date DATETIME
);


DELIMITER //

CREATE TRIGGER after_order_insert
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    INSERT INTO orders_audit(orderNumber, action_type, action_date)
    VALUES (NEW.orderNumber, 'INSERT', NOW());
END //

DELIMITER ;
SELECT * FROM orders_audit;
# Validation stock avant commande #
DELIMITER //

CREATE TRIGGER before_orderdetails_insert
BEFORE INSERT ON orderdetails
FOR EACH ROW
BEGIN
    DECLARE stock INT;

    SELECT quantityInStock INTO stock
    FROM products
    WHERE productCode = NEW.productCode;

    IF stock < NEW.quantityOrdered THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock insuffisant';
    END IF;
END //

DELIMITER ;

# Mise à jour statut client (VIP automatique) #
DELIMITER //

CREATE TRIGGER update_customer_status
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    UPDATE customers
    SET creditLimit = creditLimit + NEW.amount
    WHERE customerNumber = NEW.customerNumber;
END //

DELIMITER ;
