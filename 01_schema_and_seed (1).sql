-- ============================================================
-- FILE: 01_schema_and_seed.sql
-- Monzo Credit Analytics Portfolio Project — Alita S.
-- Schema creation + realistic seed data
-- ============================================================

-- -------------------------------------------------------
-- TABLE: customers
-- -------------------------------------------------------
CREATE TABLE customers (
    customer_id       INT PRIMARY KEY,
    age               INT,
    employment_status VARCHAR(20),   -- 'employed', 'self_employed', 'unemployed', 'student'
    annual_income_gbp INT,
    credit_score      INT,           -- 300-850 range
    region            VARCHAR(30),
    joined_date       DATE
);

-- -------------------------------------------------------
-- TABLE: loan_applications
-- -------------------------------------------------------
CREATE TABLE loan_applications (
    application_id    INT PRIMARY KEY,
    customer_id       INT REFERENCES customers(customer_id),
    applied_date      DATE,
    product_type      VARCHAR(20),   -- 'personal_loan', 'overdraft', 'flex_loan'
    requested_amount  DECIMAL(10,2),
    requested_term_months INT,
    decision         VARCHAR(10),    -- 'approved', 'declined'
    decline_reason   VARCHAR(50),    -- NULL if approved
    risk_tier        VARCHAR(10)     -- 'A', 'B', 'C', 'D', 'E' (A=lowest risk)
);

-- -------------------------------------------------------
-- TABLE: loans
-- -------------------------------------------------------
CREATE TABLE loans (
    loan_id           INT PRIMARY KEY,
    application_id    INT REFERENCES loan_applications(application_id),
    customer_id       INT REFERENCES customers(customer_id),
    disbursement_date DATE,
    loan_amount       DECIMAL(10,2),
    term_months       INT,
    apr               DECIMAL(5,2),  -- Annual Percentage Rate e.g. 24.90
    monthly_payment   DECIMAL(10,2),
    status            VARCHAR(20),   -- 'active', 'closed', 'defaulted', 'charged_off'
    close_date        DATE           -- NULL if active
);

-- -------------------------------------------------------
-- TABLE: repayments
-- -------------------------------------------------------
CREATE TABLE repayments (
    repayment_id      INT PRIMARY KEY,
    loan_id           INT REFERENCES loans(loan_id),
    due_date          DATE,
    paid_date         DATE,          -- NULL if missed
    amount_due        DECIMAL(10,2),
    amount_paid       DECIMAL(10,2), -- 0 if missed
    days_past_due     INT            -- 0 if on time
);

-- -------------------------------------------------------
-- TABLE: defaults
-- -------------------------------------------------------
CREATE TABLE defaults (
    default_id        INT PRIMARY KEY,
    loan_id           INT REFERENCES loans(loan_id),
    customer_id       INT REFERENCES customers(customer_id),
    default_date      DATE,
    days_past_due_at_default INT,
    outstanding_balance DECIMAL(10,2),
    trigger_reason    VARCHAR(50)    -- 'job_loss', 'overindebtedness', 'relationship_breakdown', 'other'
);

-- ============================================================
-- SEED DATA
-- ============================================================

INSERT INTO customers VALUES
(1,  28, 'employed',      32000, 720, 'London',        '2022-01-15'),
(2,  35, 'employed',      55000, 680, 'Manchester',    '2022-03-22'),
(3,  42, 'self_employed', 48000, 640, 'Bristol',       '2022-06-01'),
(4,  25, 'employed',      24000, 590, 'Birmingham',    '2022-07-14'),
(5,  31, 'employed',      41000, 750, 'Leeds',         '2022-08-30'),
(6,  29, 'unemployed',    12000, 480, 'Liverpool',     '2022-09-05'),
(7,  38, 'employed',      62000, 790, 'London',        '2022-10-11'),
(8,  27, 'student',       9000,  510, 'Bristol',       '2022-11-20'),
(9,  45, 'employed',      75000, 810, 'Edinburgh',     '2023-01-08'),
(10, 33, 'self_employed', 38000, 610, 'Cardiff',       '2023-02-17'),
(11, 30, 'employed',      29000, 670, 'Sheffield',     '2023-03-25'),
(12, 52, 'employed',      88000, 820, 'London',        '2023-04-10'),
(13, 24, 'employed',      22000, 545, 'Nottingham',    '2023-05-15'),
(14, 40, 'self_employed', 52000, 695, 'Glasgow',       '2023-06-22'),
(15, 36, 'employed',      44000, 730, 'Southampton',   '2023-07-01');

INSERT INTO loan_applications VALUES
(101, 1,  '2022-02-01', 'personal_loan', 5000,  24, 'approved', NULL,           'B'),
(102, 2,  '2022-04-01', 'personal_loan', 10000, 36, 'approved', NULL,           'B'),
(103, 3,  '2022-06-15', 'overdraft',     2000,  12, 'approved', NULL,           'C'),
(104, 4,  '2022-07-20', 'personal_loan', 3000,  18, 'declined', 'low_score',    'D'),
(105, 5,  '2022-09-01', 'personal_loan', 8000,  36, 'approved', NULL,           'A'),
(106, 6,  '2022-09-10', 'flex_loan',     1500,  12, 'declined', 'unemployed',   'E'),
(107, 7,  '2022-10-15', 'personal_loan', 15000, 48, 'approved', NULL,           'A'),
(108, 8,  '2022-12-01', 'overdraft',     500,   6,  'declined', 'insufficient_income', 'D'),
(109, 9,  '2023-01-15', 'personal_loan', 20000, 60, 'approved', NULL,           'A'),
(110, 10, '2023-03-01', 'personal_loan', 7000,  24, 'approved', NULL,           'C'),
(111, 11, '2023-04-01', 'flex_loan',     3500,  18, 'approved', NULL,           'B'),
(112, 12, '2023-04-15', 'personal_loan', 25000, 60, 'approved', NULL,           'A'),
(113, 13, '2023-05-20', 'overdraft',     1000,  12, 'declined', 'low_score',    'D'),
(114, 14, '2023-07-01', 'personal_loan', 12000, 36, 'approved', NULL,           'B'),
(115, 15, '2023-07-10', 'personal_loan', 9000,  36, 'approved', NULL,           'B');

INSERT INTO loans VALUES
(1001, 101, 1,  '2022-02-10', 5000,  24, 24.90, 243.50, 'closed',    '2024-02-10'),
(1002, 102, 2,  '2022-04-10', 10000, 36, 19.90, 320.00, 'active',    NULL),
(1003, 103, 3,  '2022-06-20', 2000,  12, 39.90, 184.00, 'defaulted', '2023-03-15'),
(1004, 105, 5,  '2022-09-10', 8000,  36, 14.90, 276.00, 'active',    NULL),
(1005, 107, 7,  '2022-10-20', 15000, 48, 12.90, 395.00, 'active',    NULL),
(1006, 109, 9,  '2023-01-20', 20000, 60, 9.90,  423.00, 'active',    NULL),
(1007, 110, 10, '2023-03-10', 7000,  24, 29.90, 365.00, 'defaulted', '2023-12-01'),
(1008, 111, 11, '2023-04-10', 3500,  18, 22.90, 218.00, 'active',    NULL),
(1009, 112, 12, '2023-04-20', 25000, 60, 8.90,  519.00, 'active',    NULL),
(1010, 114, 14, '2023-07-10', 12000, 36, 17.90, 432.00, 'active',    NULL),
(1011, 115, 15, '2023-07-20', 9000,  36, 16.90, 320.00, 'active',    NULL);

INSERT INTO repayments VALUES
-- Loan 1001 (closed, all paid)
(1, 1001, '2022-03-10', '2022-03-10', 243.50, 243.50, 0),
(2, 1001, '2022-04-10', '2022-04-10', 243.50, 243.50, 0),
(3, 1001, '2022-05-10', '2022-05-12', 243.50, 243.50, 2),
-- Loan 1003 (defaulted — missed payments)
(4, 1003, '2022-07-20', '2022-07-20', 184.00, 184.00, 0),
(5, 1003, '2022-08-20', '2022-08-20', 184.00, 184.00, 0),
(6, 1003, '2022-09-20', '2022-09-25', 184.00, 184.00, 5),
(7, 1003, '2022-10-20', NULL,          184.00, 0.00,   35),
(8, 1003, '2022-11-20', NULL,          184.00, 0.00,   65),
-- Loan 1007 (defaulted)
(9,  1007, '2023-04-10', '2023-04-10', 365.00, 365.00, 0),
(10, 1007, '2023-05-10', '2023-05-15', 365.00, 365.00, 5),
(11, 1007, '2023-06-10', NULL,          365.00, 0.00,   31),
(12, 1007, '2023-07-10', NULL,          365.00, 0.00,   61),
(13, 1007, '2023-08-10', NULL,          365.00, 0.00,   91),
-- Loan 1002 (active, good payer)
(14, 1002, '2022-05-10', '2022-05-10', 320.00, 320.00, 0),
(15, 1002, '2022-06-10', '2022-06-10', 320.00, 320.00, 0),
(16, 1002, '2022-07-10', '2022-07-11', 320.00, 320.00, 1);

INSERT INTO defaults VALUES
(1, 1003, 3,  '2023-03-15', 90, 920.00,  'overindebtedness'),
(2, 1007, 10, '2023-12-01', 91, 4380.00, 'job_loss');
