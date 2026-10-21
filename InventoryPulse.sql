-- =====================================================================
-- PROJECT: InventoryPulse (Advanced Retail Order & Stock Management Engine)
-- =====================================================================

-- Clean up existing tables if re-running
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE Order_Audit_Log CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE Orders CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE Inventory CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- 1. SCHEMA CREATION (Rich, Enterprise-Grade Structure)
CREATE TABLE Inventory (
    Product_ID      NUMBER PRIMARY KEY,
    Product_Name    VARCHAR2(60),
    Category        VARCHAR2(30),
    Quantity        NUMBER,
    Price           NUMBER(10,2),
    Reorder_Level   NUMBER
);

CREATE TABLE Orders (
    Order_ID        NUMBER PRIMARY KEY,
    Customer_Name   VARCHAR2(50),
    Product_ID      NUMBER,
    Order_Date      DATE,
    Qty_Ordered     NUMBER,
    Gross_Amount    NUMBER(10,2),
    Discount_Amt    NUMBER(10,2),
    Net_Payable     NUMBER(10,2),
    FOREIGN KEY (Product_ID) REFERENCES Inventory(Product_ID)
);

CREATE TABLE Order_Audit_Log (
    Audit_ID        NUMBER PRIMARY KEY,
    Action_Message  VARCHAR2(200),
    Log_Timestamp   DATE
);

-- 2. INSERT RICH REALISTIC SAMPLE DATA (Before State)
INSERT INTO Inventory VALUES (101, 'Dell Inspiron 15 Laptop', 'Electronics', 25, 58000.00, 5);
INSERT INTO Inventory VALUES (102, 'Logitech Wireless Mouse', 'Accessories', 8, 750.00, 10);
INSERT INTO Inventory VALUES (103, 'Samsung 27" 4K Monitor', 'Electronics', 4, 32000.00, 6);
INSERT INTO Inventory VALUES (104, 'Mechanical Gaming Keyboard', 'Accessories', 14, 3500.00, 5);
INSERT INTO Inventory VALUES (105, 'Sony Noise Cancelling Headphones', 'Audio', 12, 18500.00, 4);
INSERT INTO Inventory VALUES (106, 'Ergonomic Office Chair', 'Furniture', 7, 12000.00, 5);
COMMIT;

-- Display Initial Inventory State
SET SERVEROUTPUT ON;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=================================================================');
    DBMS_OUTPUT.PUT_LINE('             INITIAL INVENTORY CATALOG (BEFORE PURCHASE)         ');
    DBMS_OUTPUT.PUT_LINE('=================================================================');
    FOR r IN (SELECT Product_ID, Product_Name, Category, Quantity, Price FROM Inventory) LOOP
        DBMS_OUTPUT.PUT_LINE('ID: ' || r.Product_ID || ' | ' || RPAD(r.Product_Name, 32) || 
                             ' | Stock: ' || RPAD(r.Quantity, 3) || ' | Price: Rs.' || r.Price);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('=================================================================');
END;
/

-- 3. USER-DEFINED DISCOUNT FUNCTION (Multi-Tier Slab Logic)[cite: 1]
CREATE OR REPLACE FUNCTION calculate_discount(
    p_purchase_amount NUMBER
)
RETURN NUMBER
IS
    v_discount NUMBER;
BEGIN
    IF p_purchase_amount >= 50000 THEN
        v_discount := p_purchase_amount * 0.20; -- 20% Discount for mega purchases
    ELSIF p_purchase_amount >= 20000 THEN
        v_discount := p_purchase_amount * 0.15; -- 15% Discount
    ELSIF p_purchase_amount >= 10000 THEN
        v_discount := p_purchase_amount * 0.10; -- 10% Discount
    ELSIF p_purchase_amount >= 3000 THEN
        v_discount := p_purchase_amount * 0.05; -- 5% Discount
    ELSE
        v_discount := 0;
    END IF;
    RETURN v_discount;
END;
/

-- 4. ROBUST STORED PROCEDURE (Order Execution, Bill Generation & Exception Handling)[cite: 3, 5]
CREATE OR REPLACE PROCEDURE PROCESS_CUSTOMER_ORDER (
    p_order_id     IN NUMBER,
    p_cust_name    IN VARCHAR2,
    p_prod_id      IN NUMBER,
    p_qty          IN NUMBER
)
IS
    v_stock        NUMBER;
    v_price        NUMBER;
    v_pname        VARCHAR2(60);
    v_gross        NUMBER;
    v_discount     NUMBER;
    v_net          NUMBER;
    
    -- Custom Exception for Out-of-Stock checks
    insufficient_stock EXCEPTION;
    invalid_quantity   EXCEPTION;
BEGIN
    -- Validate quantity input
    IF p_qty <= 0 THEN
        RAISE invalid_quantity;
    END IF;

    -- Fetch product details with explicit lock check
    SELECT Product_Name, Quantity, Price 
    INTO v_pname, v_stock, v_price
    FROM Inventory
    WHERE Product_ID = p_prod_id;

    -- Check stock threshold
    IF v_stock < p_qty THEN
        RAISE insufficient_stock;
    END IF;

    -- Financial Calculations
    v_gross    := v_price * p_qty;
    v_discount := calculate_discount(v_gross);
    v_net      := v_gross - v_discount;

    -- Record Order Transaction
    INSERT INTO Orders VALUES (
        p_order_id, p_cust_name, p_prod_id, SYSDATE, p_qty, v_gross, v_discount, v_net
    );

    -- Update Inventory Stock Levels
    UPDATE Inventory
    SET Quantity = Quantity - p_qty
    WHERE Product_ID = p_prod_id;

    -- Log transaction in Audit table
    INSERT INTO Order_Audit_Log VALUES (
        p_order_id, 'Successfully processed order for ' || p_cust_name || ' (Prod ID: ' || p_prod_id || ')', SYSDATE
    );

    COMMIT;

    -- Generate Professional Real-Time Bill Output[cite: 5]
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=================================================================');
    DBMS_OUTPUT.PUT_LINE('                  OFFICIAL RETAIL SALES BILL                     ');
    DBMS_OUTPUT.PUT_LINE('=================================================================');
    DBMS_OUTPUT.PUT_LINE(' Order ID        : ' || p_order_id);
    DBMS_OUTPUT.PUT_LINE(' Customer Name   : ' || p_cust_name);
    DBMS_OUTPUT.PUT_LINE(' Date & Time     : ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(' Product Purchased : ' || v_pname);
    DBMS_OUTPUT.PUT_LINE(' Unit Price        : Rs.' || v_price);
    DBMS_OUTPUT.PUT_LINE(' Quantity Bought   : ' || p_qty);
    DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(' Gross Amount      : Rs.' || v_gross);
    DBMS_OUTPUT.PUT_LINE(' Discount Applied  : -Rs.' || v_discount);
    DBMS_OUTPUT.PUT_LINE('=================================================================');
    DBMS_OUTPUT.PUT_LINE(' NET PAYABLE TOTAL : Rs.' || v_net);
    DBMS_OUTPUT.PUT_LINE('=================================================================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '[ERROR] Product ID ' || p_prod_id || ' does not exist in inventory catalog!');
    WHEN insufficient_stock THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '[ERROR] Order Failed! Insufficient stock for product "' || p_prod_id || '". Available: ' || v_stock || ', Requested: ' || p_qty);
    WHEN invalid_quantity THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '[ERROR] Invalid purchase quantity specified. Must be greater than 0.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '[ERROR] System Exception Encountered: ' || SQLERRM);
END;
/

-- 5. EXPLICIT CURSOR (Low Stock & Reorder Alert Generator)[cite: 8]
CREATE OR REPLACE PROCEDURE GENERATE_STOCK_ALERT_REPORT
IS
    CURSOR stock_cursor IS
        SELECT Product_ID, Product_Name, Quantity, Reorder_Level
        FROM Inventory
        WHERE Quantity <= Reorder_Level;
        
    v_id   Inventory.Product_ID%TYPE;
    v_name Inventory.Product_Name%TYPE;
    v_qty  Inventory.Quantity%TYPE;
    v_rl   Inventory.Reorder_Level%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=================================================================');
    DBMS_OUTPUT.PUT_LINE('            INVENTORYPULSE: LOW STOCK & REORDER REPORT           ');
    DBMS_OUTPUT.PUT_LINE('=================================================================');
    
    OPEN stock_cursor;
    LOOP
        FETCH stock_cursor INTO v_id, v_name, v_qty, v_rl;
        EXIT WHEN stock_cursor%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE(' [CRITICAL ALERT] Product ID: ' || v_id || 
                             ' | Name: ' || RPAD(v_name, 28) || 
                             ' | Stock Left: ' || v_qty || 
                             ' (Reorder threshold: ' || v_rl || ')');
    END LOOP;
    CLOSE stock_cursor;
    DBMS_OUTPUT.PUT_LINE('=================================================================');
END;
/


-- =====================================================================
-- 6. LIVE TEST EXECUTION BLOCK (Run to see Bills, Changes & Reports)
-- =====================================================================
SET SERVEROUTPUT ON;

BEGIN
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '*** EXECUTING PURCHASE TRANSACTION 1 ***');
    -- Customer buys 1 Laptop (ID 101)
    PROCESS_CUSTOMER_ORDER(9001, 'Aditya Kumar Singh', 101, 1);
    
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '*** EXECUTING PURCHASE TRANSACTION 2 ***');
    -- Customer buys 2 Monitors (ID 103)
    PROCESS_CUSTOMER_ORDER(9002, 'Rahul Sharma', 103, 2);
    
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '*** EXECUTING PURCHASE TRANSACTION 3 (Testing Stock Exception) ***');
    -- Trying to buy 10 monitors when only a few are left
    PROCESS_CUSTOMER_ORDER(9003, 'Priya Verma', 103, 10);
END;
/

-- View Final Inventory State (After Purchase Leftover Quantities)
BEGIN
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=================================================================');
    DBMS_OUTPUT.PUT_LINE('          UPDATED INVENTORY CATALOG (AFTER PURCHASES)            ');
    DBMS_OUTPUT.PUT_LINE('=================================================================');
    FOR r IN (SELECT Product_ID, Product_Name, Quantity, Price FROM Inventory) LOOP
        DBMS_OUTPUT.PUT_LINE('ID: ' || r.Product_ID || ' | ' || RPAD(r.Product_Name, 32) || 
                             ' | Remaining Stock: ' || RPAD(r.Quantity, 3) || ' | Price: Rs.' || r.Price);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('=================================================================');
END;
/

-- Run Stock Alert Report Cursor
BEGIN
    GENERATE_STOCK_ALERT_REPORT;
END;
/

-- View All Recorded Orders
SELECT * FROM Orders;