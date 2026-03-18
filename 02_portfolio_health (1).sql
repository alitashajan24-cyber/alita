-- ============================================================
-- FILE: 02_portfolio_health.sql
-- Core portfolio monitoring — the kind of queries a Credit
-- Analyst runs daily/weekly at a lender like Monzo
-- ============================================================

-- -------------------------------------------------------
-- Q1: Portfolio summary snapshot
-- How much is lent out, how many active loans, avg APR?
-- -------------------------------------------------------
SELECT
    status,
    COUNT(loan_id)                        AS loan_count,
    SUM(loan_amount)                      AS total_lent_gbp,
    ROUND(AVG(loan_amount), 2)            AS avg_loan_size,
    ROUND(AVG(apr), 2)                    AS avg_apr,
    ROUND(AVG(term_months), 0)            AS avg_term_months
FROM loans
GROUP BY status
ORDER BY loan_count DESC;

/*
  Expected insight: You can see the split between active/closed/defaulted
  and monitor whether the defaulted share is growing over time.
*/


-- -------------------------------------------------------
-- Q2: Monthly origination volumes and value
-- Track how much new lending is being booked each month
-- -------------------------------------------------------
SELECT
    DATE_TRUNC('month', disbursement_date) AS origination_month,
    COUNT(loan_id)                          AS loans_originated,
    SUM(loan_amount)                        AS total_value_gbp,
    ROUND(AVG(apr), 2)                      AS avg_apr
FROM loans
GROUP BY 1
ORDER BY 1;


-- -------------------------------------------------------
-- Q3: Approval and decline rates by product type
-- Critical for understanding underwriting funnel
-- -------------------------------------------------------
SELECT
    product_type,
    COUNT(*)                                          AS total_applications,
    SUM(CASE WHEN decision = 'approved' THEN 1 ELSE 0 END) AS approved,
    SUM(CASE WHEN decision = 'declined' THEN 1 ELSE 0 END) AS declined,
    ROUND(
        100.0 * SUM(CASE WHEN decision = 'approved' THEN 1 ELSE 0 END) / COUNT(*),
        1
    )                                                 AS approval_rate_pct
FROM loan_applications
GROUP BY product_type
ORDER BY total_applications DESC;


-- -------------------------------------------------------
-- Q4: Decline reason breakdown
-- Where are we losing applicants and why?
-- -------------------------------------------------------
SELECT
    decline_reason,
    COUNT(*)                                     AS declined_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS pct_of_all_declines
FROM loan_applications
WHERE decision = 'declined'
GROUP BY decline_reason
ORDER BY declined_count DESC;


-- -------------------------------------------------------
-- Q5: Customers with any missed payment (30+ DPD)
-- Early warning list — who is showing stress signals?
-- -------------------------------------------------------
SELECT
    l.loan_id,
    l.customer_id,
    l.loan_amount,
    l.apr,
    MAX(r.days_past_due)        AS max_days_past_due,
    COUNT(CASE WHEN r.days_past_due >= 30 THEN 1 END) AS missed_payments_30dpd
FROM loans l
JOIN repayments r ON l.loan_id = r.loan_id
WHERE l.status = 'active'
GROUP BY l.loan_id, l.customer_id, l.loan_amount, l.apr
HAVING MAX(r.days_past_due) >= 1
ORDER BY max_days_past_due DESC;
