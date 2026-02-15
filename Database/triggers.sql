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