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
