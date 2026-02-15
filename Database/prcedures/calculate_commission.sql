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

# Gestion stock #

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