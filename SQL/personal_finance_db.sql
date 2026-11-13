
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
-- FINANCIAL_TRANSACTION Entity, TRANSACTION is a reserved keyword
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
