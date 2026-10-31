
-- Create the database
CREATE DATABASE IF NOT EXISTS personal_finance_db;

-- Select the database
USE personal_finance_db;

-- ============================================
-- USER Entity
-- ============================================
CREATE TABLE `USER` (
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
    target_date DATE,

    CONSTRAINT fk_savings_goal_user
        FOREIGN KEY (user_id)
        REFERENCES `USER`(user_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
