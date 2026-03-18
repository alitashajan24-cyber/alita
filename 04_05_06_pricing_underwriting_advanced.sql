-- ============================================================
-- FILE: 04_pricing_analysis.sql
-- APR pricing impact on portfolio performance
-- This directly maps to the JD: "pricing dynamics on portfolio performance"
-- ============================================================

-- -------------------------------------------------------
-- Q1: APR banding — volume and default rate by price point
-- Does higher APR = higher default? (it should, but how much?)
-- -------------------------------------------------------
SELECT
    CASE
        WHEN apr < 15          THEN 'Under 15% APR'
        WHEN apr BETWEEN 15 AND 24.99 THEN '15-24.99% APR'
        WHEN apr BETWEEN 25 AND 34.99 THEN '25-34.99% APR'
        WHEN apr >= 35         THEN '35%+ APR'
    END                                                         AS apr_band,
    COUNT(loan_id)                                              AS loan_count,
    ROUND(AVG(loan_amount), 2)                                  AS avg_loan_size,
    SUM(CASE WHEN status = 'defaulted' THEN 1 ELSE 0 END)      AS defaults,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'defaulted' THEN 1 ELSE 0 END)
        / COUNT(loan_id), 1
    )                                                           AS default_rate_pct
FROM loans
GROUP BY 1
ORDER BY MIN(apr);


-- -------------------------------------------------------
-- Q2: Revenue at risk — expected interest income vs defaults
-- Simplified: total interest revenue vs loss from defaults
-- -------------------------------------------------------
SELECT
    l.loan_id,
    l.loan_amount,
    l.apr,
    l.term_months,
    -- Simple approximation of total interest
    ROUND((l.monthly_payment * l.term_months) - l.loan_amount, 2) AS est_interest_revenue,
    COALESCE(d.outstanding_balance, 0)                             AS loss_if_defaulted,
    l.status
FROM loans l
LEFT JOIN defaults d ON l.loan_id = d.loan_id
ORDER BY est_interest_revenue DESC;


-- ============================================================
-- FILE: 05_underwriting_strategy.sql
-- Evaluating underwriting cut-offs and strategy performance
-- ============================================================

-- -------------------------------------------------------
-- Q1: What would happen if we tightened the credit score cut-off?
-- Simulating a policy change: reject anyone below score 600
-- -------------------------------------------------------
SELECT
    'Current Policy'                          AS policy,
    COUNT(*)                                  AS approved_loans,
    SUM(loan_amount)                          AS total_lent,
    SUM(CASE WHEN l.status = 'defaulted' THEN 1 ELSE 0 END) AS defaults
FROM loans l
JOIN loan_applications la ON l.application_id = la.application_id
JOIN customers c ON l.customer_id = c.customer_id

UNION ALL

SELECT
    'Tightened (Score 600+)'                  AS policy,
    COUNT(*)                                  AS approved_loans,
    SUM(loan_amount)                          AS total_lent,
    SUM(CASE WHEN l.status = 'defaulted' THEN 1 ELSE 0 END) AS defaults
FROM loans l
JOIN loan_applications la ON l.application_id = la.application_id
JOIN customers c ON l.customer_id = c.customer_id
WHERE c.credit_score >= 600;

/*
  INSIGHT: This is a classic underwriting strategy question.
  Tightening cuts defaults but reduces volume/revenue. The job
  of a Credit Analyst is to find the optimal balance point.
*/


-- -------------------------------------------------------
-- Q2: Income-to-loan ratio analysis
-- Are we lending too much relative to customer income?
-- -------------------------------------------------------
SELECT
    c.customer_id,
    c.annual_income_gbp,
    l.loan_amount,
    ROUND(l.loan_amount / c.annual_income_gbp * 100, 1)  AS loan_to_income_pct,
    l.apr,
    la.risk_tier,
    l.status,
    CASE
        WHEN l.loan_amount / c.annual_income_gbp > 0.3 THEN 'High LTI (>30%)'
        WHEN l.loan_amount / c.annual_income_gbp > 0.15 THEN 'Medium LTI'
        ELSE 'Low LTI (<15%)'
    END                                                    AS lti_band
FROM customers c
JOIN loan_applications la ON c.customer_id = la.customer_id
JOIN loans l ON la.application_id = l.application_id
ORDER BY loan_to_income_pct DESC;


-- ============================================================
-- FILE: 06_advanced_window_functions.sql
-- CTEs, window functions, cohort analysis
-- ============================================================

-- -------------------------------------------------------
-- Q1: Running total of lending by month (window function)
-- -------------------------------------------------------
SELECT
    DATE_TRUNC('month', disbursement_date)   AS month,
    SUM(loan_amount)                          AS monthly_originations,
    SUM(SUM(loan_amount)) OVER (
        ORDER BY DATE_TRUNC('month', disbursement_date)
    )                                         AS cumulative_total_lent
FROM loans
GROUP BY 1
ORDER BY 1;


-- -------------------------------------------------------
-- Q2: Rank customers by loan size within each risk tier
-- -------------------------------------------------------
SELECT
    c.customer_id,
    la.risk_tier,
    l.loan_amount,
    RANK() OVER (
        PARTITION BY la.risk_tier
        ORDER BY l.loan_amount DESC
    )                          AS rank_within_tier,
    l.status
FROM customers c
JOIN loan_applications la ON c.customer_id = la.customer_id
JOIN loans l ON la.application_id = l.application_id;


-- -------------------------------------------------------
-- Q3: CTE — Identify at-risk active loans
-- Multi-step logic using Common Table Expressions
-- -------------------------------------------------------
WITH payment_behaviour AS (
    -- Step 1: Summarise repayment history per loan
    SELECT
        loan_id,
        COUNT(*)                                         AS total_payments,
        SUM(CASE WHEN days_past_due >= 30 THEN 1 ELSE 0 END) AS late_payments_30dpd,
        MAX(days_past_due)                               AS max_dpd
    FROM repayments
    GROUP BY loan_id
),
at_risk_loans AS (
    -- Step 2: Flag loans showing stress signals
    SELECT
        l.loan_id,
        l.customer_id,
        l.loan_amount,
        l.apr,
        la.risk_tier,
        pb.late_payments_30dpd,
        pb.max_dpd,
        CASE
            WHEN pb.max_dpd >= 60              THEN 'HIGH RISK'
            WHEN pb.late_payments_30dpd >= 2   THEN 'MEDIUM RISK'
            WHEN pb.late_payments_30dpd = 1    THEN 'WATCH'
            ELSE 'LOW RISK'
        END                                              AS risk_flag
    FROM loans l
    JOIN loan_applications la ON l.application_id = la.application_id
    JOIN payment_behaviour pb ON l.loan_id = pb.loan_id
    WHERE l.status = 'active'
)
-- Step 3: Return only flagged loans for review
SELECT *
FROM at_risk_loans
WHERE risk_flag != 'LOW RISK'
ORDER BY
    CASE risk_flag
        WHEN 'HIGH RISK' THEN 1
        WHEN 'MEDIUM RISK' THEN 2
        WHEN 'WATCH' THEN 3
    END,
    loan_amount DESC;

/*
  This CTE pattern — breaking complex logic into named steps —
  is exactly what you'd use in a Monzo take-home task or
  production Looker/dbt model.
*/


-- -------------------------------------------------------
-- Q4: Month-over-month change in originations (LAG function)
-- -------------------------------------------------------
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', disbursement_date) AS month,
        COUNT(loan_id)                          AS loan_count,
        SUM(loan_amount)                        AS total_originated
    FROM loans
    GROUP BY 1
)
SELECT
    month,
    loan_count,
    total_originated,
    LAG(total_originated) OVER (ORDER BY month) AS prev_month_total,
    ROUND(
        100.0 * (total_originated - LAG(total_originated) OVER (ORDER BY month))
        / NULLIF(LAG(total_originated) OVER (ORDER BY month), 0),
        1
    )                                            AS mom_growth_pct
FROM monthly
ORDER BY month;
