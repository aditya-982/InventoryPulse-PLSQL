-- ========================================================
-- PROJECT: InventoryPulse (Order & Stock Management)
-- ========================================================

-- 1. SCHEMA CREATION
CREATE TABLE Inventory (
    Product_ID NUMBER PRIMARY KEY,
    Product_Name VARCHAR2(50),
    Quantity NUMBER,
    Price NUMBER(10,2)
);

CREATE TABLE Orders (
    Order_ID NUMBER PRIMARY KEY,
    Product_ID NUMBER,
    Order_Date DATE,
    Quantity_Ordered NUMBER,
    Total_Price NUMBER(10,2),
    Discount_Applied NUMBER(10,2),
    FOREIGN KEY (Product_ID) REFERENCES Inventory(Product_ID)
);

-- 2. SAMPLE DATA INSERTION
INSERT INTO Inventory VALUES (101, 'Laptop', 25, 55000);
INSERT INTO Inventory VALUES (102, 'Mouse', 8, 500);
INSERT INTO Inventory VALUES (103, 'Monitor', 5, 12000);
INSERT INTO Inventory VALUES (104, 'Keyboard', 15, 1200);
COMMIT;

-- 3. USER-DEFINED DISCOUNT FUNCTION
CREATE OR REPLACE FUNCTION calculate_discount(
    purchase_amount NUMBER
)
RETURN NUMBER
IS
    discount NUMBER;
BEGIN
    IF purchase_amount >= 50000 THEN
        discount := purchase_amount * 0.20;
    ELSIF purchase_amount >= 10000 THEN
        discount := purchase_amount * 0.10;
    ELSIF purchase_amount >= 2000 THEN
        discount := purchase_amount * 0.05;
    ELSE
        discount := 0;
    END IF;
    RETURN discount;
END;
/

-- 4. STORED PROCEDURE FOR ORDER PROCESSING
CREATE OR REPLACE PROCEDURE PROCESS_CUSTOMER_ORDER (
    p_order_id     IN NUMBER,
    p_prod_id      IN NUMBER,
    p_qty          IN NUMBER
)
IS
    v_stock        NUMBER;
    v_price        NUMBER;
    v_gross_total  NUMBER;
    v_discount     NUMBER;
    v_net_total    NUMBER;
BEGIN
    SELECT Quantity, Price 
    INTO v_stock, v_price
    FROM Inventory
    WHERE Product_ID = p_prod_id;

    IF v_stock >= p_qty THEN
        v_gross_total := v_price * p_qty;
        v_discount := calculate_discount(v_gross_total);
        v_net_total := v_gross_total - v_discount;

        INSERT INTO Orders VALUES (
            p_order_id, p_prod_id, SYSDATE, p_qty, v_net_total, v_discount
        );

        UPDATE Inventory
        SET Quantity = Quantity - p_qty
        WHERE Product_ID = p_prod_id;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Success: Order processed. Net Amount Paid: ' || v_net_total);
    ELSE
        DBMS_OUTPUT.PUT_LINE('Error: Insufficient stock available.');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: Product ID not found.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- 5. EXPLICIT CURSOR (LOW-STOCK REPORT)
SET SERVEROUTPUT ON;

DECLARE
    CURSOR low_stock_cursor IS
        SELECT Product_ID, Product_Name, Quantity
        FROM Inventory
        WHERE Quantity < 10;
        
    v_pid   Inventory.Product_ID%TYPE;
    v_pname Inventory.Product_Name%TYPE;
    v_qty   Inventory.Quantity%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('    INVENTORY PULSE: LOW STOCK REPORT   ');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    OPEN low_stock_cursor;
    LOOP
        FETCH low_stock_cursor INTO v_pid, v_pname, v_qty;
        EXIT WHEN low_stock_cursor%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE(
            'Alert -> ID: ' || v_pid || 
            ' | Name: ' || RPAD(v_pname, 10) || 
            ' | Remaining Qty: ' || v_qty
        );
    END LOOP;
    CLOSE low_stock_cursor;
    
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/

-- 6. EXECUTION & VERIFICATION
BEGIN
    PROCESS_CUSTOMER_ORDER(501, 101, 2);
END;
/

SELECT * FROM Inventory;
SELECT * FROM Orders;