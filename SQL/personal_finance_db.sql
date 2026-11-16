
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

