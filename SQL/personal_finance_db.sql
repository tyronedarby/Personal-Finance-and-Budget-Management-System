
-- Create the database
CREATE DATABASE IF NOT EXISTS personal_finance_db;

-- Select the database
USE personal_finance_db;

START TRANSACTION;

-- ============================================
-- APP_USER Entity, USER is a reserved keyword
-- ============================================
CREATE TABLE APP_USER (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE
);

-- ============================================
-- SAVINGS_GOAL Entity
-- ============================================
CREATE TABLE SAVINGS_GOAL (
    goal_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    goal_name VARCHAR(100) NOT NULL,
    target_amount DECIMAL(12,2) NOT NULL,
    current_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    target_date DATE NOT NULL,

    CONSTRAINT fk_savings_goal_user
        FOREIGN KEY (user_id)
        REFERENCES APP_USER(user_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- ============================================
-- CATEGORY Entity
-- ============================================
CREATE TABLE CATEGORY (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    category_type VARCHAR(100) NOT NULL
);

-- ============================================
-- BUDGET Entity
-- ============================================

CREATE TABLE BUDGET (
    budget_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    category_id INT NOT NULL,
    budget_period VARCHAR(20) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    limit_amount DECIMAL(12,2) NOT NULL CHECK (limit_amount > 0),

    CONSTRAINT fk_end_date_sanity_check
        CHECK (end_date > start_date),
    
    CONSTRAINT fk_budget_user
        FOREIGN KEY (user_id)
        REFERENCES APP_USER(user_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    
    CONSTRAINT fk_budget_category
        FOREIGN KEY (category_id)
        REFERENCES CATEGORY(category_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- ============================================
-- MONETARY_TRANSACTION Entity, TRANSACTION is a reserved keyword
-- ============================================
CREATE TABLE MONETARY_TRANSACTION (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    category_id INT NOT NULL,
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    transaction_date DATE NOT NULL,
    type VARCHAR(100),
    description VARCHAR(1000),

    CONSTRAINT fk_transaction_user
        FOREIGN KEY (user_id)
        REFERENCES APP_USER(user_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_transaction_category
        FOREIGN KEY (category_id)
        REFERENCES CATEGORY(category_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

COMMIT;

-- ============================================
-- Indexes to keep searches fast
-- ============================================
CREATE INDEX idx_txn_user_date     ON MONETARY_TRANSACTION (user_id, transaction_date);
CREATE INDEX idx_txn_user_category ON MONETARY_TRANSACTION (user_id, category_id);
CREATE INDEX idx_txn_user_amount   ON MONETARY_TRANSACTION (user_id, amount);

-- ============================================
-- Search procedure
-- Every filter is optional: pass NULL to skip it.
-- ============================================
DROP PROCEDURE IF EXISTS sp_search_transactions;

DELIMITER $$

CREATE PROCEDURE sp_search_transactions (
    IN p_user_id      INT,             
    IN p_keyword      VARCHAR(100),    
    IN p_category_id  INT,
    IN p_type         VARCHAR(100),
    IN p_min_amount   DECIMAL(12,2),
    IN p_max_amount   DECIMAL(12,2),
    IN p_start_date   DATE,
    IN p_end_date     DATE,
    IN p_sort_by      VARCHAR(20),     
    IN p_sort_dir     VARCHAR(4),     
    IN p_limit        INT,             
    IN p_offset       INT              
)
BEGIN
    DECLARE v_limit  INT DEFAULT 50;
    DECLARE v_offset INT DEFAULT 0;
    DECLARE v_sort   VARCHAR(20);
    DECLARE v_dir    VARCHAR(4);

    -- Sanitize paging and sorting inputs
    IF p_limit IS NOT NULL AND p_limit > 0 THEN
        SET v_limit = LEAST(p_limit, 200);
    END IF;
    IF p_offset IS NOT NULL AND p_offset > 0 THEN
        SET v_offset = p_offset;
    END IF;

    SET v_sort = LOWER(COALESCE(p_sort_by, 'date'));
    SET v_dir  = UPPER(COALESCE(p_sort_dir, 'DESC'));
    IF v_sort NOT IN ('date', 'amount', 'category') THEN SET v_sort = 'date'; END IF;
    IF v_dir  NOT IN ('ASC', 'DESC')                THEN SET v_dir  = 'DESC'; END IF;

    SELECT
        t.transaction_id,
        t.transaction_date,
        t.amount,
        t.type,
        t.description,
        c.category_id,
        c.category_name,
        c.category_type
    FROM MONETARY_TRANSACTION t
    JOIN CATEGORY c ON c.category_id = t.category_id
    WHERE t.user_id = p_user_id
      AND (p_category_id IS NULL OR t.category_id = p_category_id)
      AND (p_type        IS NULL OR t.type = p_type)
      AND (p_min_amount  IS NULL OR t.amount >= p_min_amount)
      AND (p_max_amount  IS NULL OR t.amount <= p_max_amount)
      AND (p_start_date  IS NULL OR t.transaction_date >= p_start_date)
      AND (p_end_date    IS NULL OR t.transaction_date <= p_end_date)
      AND (
            p_keyword IS NULL
            OR t.description   LIKE CONCAT('%', p_keyword, '%')
            OR c.category_name LIKE CONCAT('%', p_keyword, '%')
          )
    ORDER BY
        CASE WHEN v_sort = 'date'     AND v_dir = 'ASC'  THEN t.transaction_date END ASC,
        CASE WHEN v_sort = 'date'     AND v_dir = 'DESC' THEN t.transaction_date END DESC,
        CASE WHEN v_sort = 'amount'   AND v_dir = 'ASC'  THEN t.amount END ASC,
        CASE WHEN v_sort = 'amount'   AND v_dir = 'DESC' THEN t.amount END DESC,
        CASE WHEN v_sort = 'category' AND v_dir = 'ASC'  THEN c.category_name END ASC,
        CASE WHEN v_sort = 'category' AND v_dir = 'DESC' THEN c.category_name END DESC,
        t.transaction_id DESC            
    LIMIT v_limit OFFSET v_offset;
END$$

DELIMITER ;

SHOW TABLES;

-- Insert sample data

INSERT INTO APP_USER (name, email)
VALUES
('John Smith', 'john@example.com'),
('Emily Johnson', 'emily@example.com'),
('Michael Brown', 'michael@example.com');

INSERT INTO CATEGORY (category_name, category_type)
VALUES
('Groceries', 'Expense'),
('Entertainment', 'Expense'),
('Rent', 'Expense'),
('Utilities', 'Expense'),
('Transportation', 'Expense'),
('Shopping', 'Expense'),
('Salary', 'Income'),
('Freelance', 'Income');

INSERT INTO BUDGET
(user_id, category_id, budget_period, start_date, end_date, limit_amount)
VALUES
(1, 1, 'monthly', '2026-11-01', '2026-11-30', 400.00),
(1, 2, 'monthly', '2026-11-01', '2026-11-30', 200.00),
(1, 3, 'monthly', '2026-11-01', '2026-11-30', 1000.00),
(1, 4, 'monthly', '2026-11-01', '2026-11-30', 150.00),
(2, 1, 'monthly', '2026-11-01', '2026-11-30', 350.00),
(2, 5, 'monthly', '2026-11-01', '2026-11-30', 250.00),
(3, 2, 'monthly', '2026-11-01', '2026-11-30', 300.00),
(3, 6, 'monthly', '2026-11-01', '2026-11-30', 200.00);

INSERT INTO MONETARY_TRANSACTION
(user_id, category_id, amount, transaction_date, type, description)
VALUES
(1, 1, 120.00, '2026-11-02', 'Expense', 'Weekly groceries'),
(1, 1, 95.00, '2026-11-09', 'Expense', 'Food shopping'),
(1, 2, 250.00, '2026-11-05', 'Expense', 'Video games'),
(1, 3, 950.00, '2026-11-01', 'Expense', 'Monthly rent'),
(1, 4, 175.00, '2026-11-07', 'Expense', 'Electricity and water'),
(1, 7, 2500.00, '2026-11-01', 'Income', 'Paycheck'),
(2, 1, 150.00, '2026-11-03', 'Expense', 'Groceries'),
(2, 5, 275.00, '2026-11-06', 'Expense', 'Transportation'),
(2, 7, 3000.00, '2026-11-01', 'Income', 'Salary'),
(3, 2, 180.00, '2026-11-04', 'Expense', 'Entertainment'),
(3, 6, 225.00, '2026-11-08', 'Expense', 'Shopping'),
(3, 8, 1200.00, '2026-11-02', 'Income', 'Freelance work');

INSERT INTO SAVINGS_GOAL
(user_id, goal_name, target_amount, current_amount, target_date)
VALUES
(1, 'Emergency Fund', 5000.00, 1200.00, '2027-12-31'),
(1, 'Vacation Fund', 2000.00, 750.00, '2027-06-30'),
(2, 'New Laptop', 1500.00, 400.00, '2027-05-31'),
(2, 'Car Down Payment', 8000.00, 2500.00, '2028-01-31'),
(3, 'Gaming PC', 2500.00, 900.00, '2027-08-31'),
(3, 'Emergency Savings', 4000.00, 1000.00, '2027-12-31');

-- Verify records

SELECT * FROM APP_USER;
SELECT * FROM CATEGORY;
SELECT * FROM BUDGET;
SELECT * FROM MONETARY_TRANSACTION;
SELECT * FROM SAVINGS_GOAL;

SELECT 'APP_USER' AS table_name, COUNT(*) AS total FROM APP_USER
UNION ALL
SELECT 'CATEGORY', COUNT(*) FROM CATEGORY
UNION ALL
SELECT 'BUDGET', COUNT(*) FROM BUDGET
UNION ALL
SELECT 'MONETARY_TRANSACTION', COUNT(*) FROM MONETARY_TRANSACTION
UNION ALL
SELECT 'SAVINGS_GOAL', COUNT(*) FROM SAVINGS_GOAL;

-- Search transactions

SELECT *
FROM MONETARY_TRANSACTION
WHERE user_id = 1
ORDER BY transaction_date DESC;

-- JOIN query

SELECT
    u.name AS user_name,
    c.category_name,
    t.amount,
    t.transaction_date,
    t.type,
    t.description
FROM MONETARY_TRANSACTION t
JOIN APP_USER u ON t.user_id = u.user_id
JOIN CATEGORY c ON t.category_id = c.category_id
ORDER BY t.transaction_date, t.transaction_id;

-- Aggregate query

SELECT
    u.name AS user_name,
    c.category_name,
    SUM(t.amount) AS total_spent,
    COUNT(t.transaction_id) AS transaction_count
FROM MONETARY_TRANSACTION t
JOIN APP_USER u ON t.user_id = u.user_id
JOIN CATEGORY c ON t.category_id = c.category_id
WHERE t.type = 'Expense'
GROUP BY u.user_id, u.name, c.category_id, c.category_name
ORDER BY u.name, c.category_name;

-- Overspending detection

SELECT
    u.name AS user_name,
    c.category_name,
    b.limit_amount AS budget_limit,
    COALESCE(SUM(t.amount), 0) AS total_spent,
    COALESCE(SUM(t.amount), 0) - b.limit_amount AS amount_over_budget
FROM BUDGET b
JOIN APP_USER u ON b.user_id = u.user_id
JOIN CATEGORY c ON b.category_id = c.category_id
LEFT JOIN MONETARY_TRANSACTION t
    ON t.user_id = b.user_id
    AND t.category_id = b.category_id
    AND t.type = 'Expense'
    AND t.transaction_date BETWEEN b.start_date AND b.end_date
GROUP BY b.budget_id, u.name, c.category_name, b.limit_amount
HAVING total_spent > b.limit_amount
ORDER BY amount_over_budget DESC;

-- Spending recommendations

SELECT
    spending.user_name,
    spending.category_name,
    spending.budget_limit,
    spending.total_spent,
    spending.amount_over_budget,
    CASE
        WHEN spending.category_name = 'Entertainment'
            THEN 'Reduce entertainment purchases and subscriptions.'
        WHEN spending.category_name = 'Utilities'
            THEN 'Reduce electricity and water usage.'
        WHEN spending.category_name = 'Transportation'
            THEN 'Consider carpooling or reducing transportation costs.'
        WHEN spending.category_name = 'Shopping'
            THEN 'Limit unnecessary purchases and prioritize essentials.'
        ELSE 'Review spending and reduce expenses in this category.'
    END AS recommendation
FROM (
    SELECT
        b.budget_id,
        u.name AS user_name,
        c.category_name,
        b.limit_amount AS budget_limit,
        COALESCE(SUM(t.amount), 0) AS total_spent,
        COALESCE(SUM(t.amount), 0) - b.limit_amount AS amount_over_budget
    FROM BUDGET b
    JOIN APP_USER u ON b.user_id = u.user_id
    JOIN CATEGORY c ON b.category_id = c.category_id
    LEFT JOIN MONETARY_TRANSACTION t
        ON t.user_id = b.user_id
        AND t.category_id = b.category_id
        AND t.type = 'Expense'
        AND t.transaction_date BETWEEN b.start_date AND b.end_date
    GROUP BY b.budget_id, u.name, c.category_name, b.limit_amount
) AS spending
WHERE spending.amount_over_budget > 0
ORDER BY spending.amount_over_budget DESC;

-- UPDATE demonstration: run separately when needed

-- UPDATE BUDGET
-- SET limit_amount = 300.00
-- WHERE budget_id = 2;

-- SELECT * FROM BUDGET WHERE budget_id = 2;

-- UPDATE BUDGET
-- SET limit_amount = 200.00
-- WHERE budget_id = 2;

-- DELETE demonstration: run separately when needed

-- INSERT INTO MONETARY_TRANSACTION
-- (user_id, category_id, amount, transaction_date, type, description)
-- VALUES
-- (1, 1, 10.00, '2026-11-10', 'Expense', 'Temporary Delete Test');

-- DELETE FROM MONETARY_TRANSACTION
-- WHERE user_id = 1
-- AND description = 'Temporary Delete Test';

-- Constraint tests: run individually when needed

-- INSERT INTO BUDGET
-- (user_id, category_id, budget_period, start_date, end_date, limit_amount)
-- VALUES
-- (99999, 1, 'monthly', '2026-11-01', '2026-11-30', 100.00);

-- INSERT INTO APP_USER (name, email)
-- VALUES ('Test User', 'john@example.com');

-- INSERT INTO BUDGET
-- (user_id, category_id, budget_period, start_date, end_date, limit_amount)
-- VALUES
-- (1, 1, 'monthly', '2026-12-01', '2026-12-31', -100.00);

-- INSERT INTO APP_USER (name, email)
-- VALUES (NULL, 'testnull@example.com');
