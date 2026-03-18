-- ============================================================
-- FILE: 03_risk_and_default_analysis.sql
-- Default rate analysis by risk tier — core credit analytics
-- ============================================================

-- -------------------------------------------------------
-- Q1: Default rate by risk tier
-- Key metric: what % of each tier defaults?
-- -------------------------------------------------------
SELECT
    la.risk_tier,
    COUNT(l.loan_id)                                                  AS loans_originated,
    SUM(CASE WHEN l.status = 'defaulted' THEN 1 ELSE 0 END)          AS defaults,
    ROUND(
        100.0 * SUM(CASE WHEN l.status = 'defaulted' THEN 1 ELSE 0 END)
        / COUNT(l.loan_id), 2
    )                                                                 AS default_rate_pct,
    ROUND(AVG(l.apr), 2)                                              AS avg_apr,
    ROUND(AVG(l.loan_amount), 2)                                      AS avg_loan_size
FROM loan_applications la
JOIN loans l ON la.application_id = l.application_id
GROUP BY la.risk_tier
ORDER BY la.risk_tier;

/*
  INSIGHT: Higher risk tiers (D, E) should show higher default rates.
  If tier A is defaulting at the same rate as tier C — your risk model
  needs recalibration. This is the core of underwriting strategy review.
*/


-- -------------------------------------------------------
-- Q2: Loss given default — how much do we lose per default?
-- -------------------------------------------------------
SELECT
    d.default_id,
    d.loan_id,
    l.loan_amount                                      AS original_loan,
    d.outstanding_balance                              AS balance_at_default,
    ROUND(d.outstanding_balance / l.loan_amount * 100, 1) AS pct_outstanding,
    d.trigger_reason,
    d.days_past_due_at_default
FROM defaults d
JOIN loans l ON d.loan_id = l.loan_id
ORDER BY d.outstanding_balance DESC;


-- -------------------------------------------------------
-- Q3: Default rate by trigger reason
-- Helps model stress scenarios (e.g., recession = more job_loss)
-- -------------------------------------------------------
SELECT
    trigger_reason,
    COUNT(*)                          AS default_count,
    ROUND(AVG(outstanding_balance), 2) AS avg_loss_gbp,
    ROUND(AVG(days_past_due_at_default), 0) AS avg_dpd_at_default
FROM defaults
GROUP BY trigger_reason
ORDER BY avg_loss_gbp DESC;


-- -------------------------------------------------------
-- Q4: Customers with high default risk profile
-- Combining credit score, income, and payment behaviour
-- -------------------------------------------------------
SELECT
    c.customer_id,
    c.credit_score,
    c.annual_income_gbp,
    c.employment_status,
    la.risk_tier,
    l.loan_amount,
    l.apr,
    MAX(r.days_past_due)   AS max_dpd,
    l.status
FROM customers c
JOIN loan_applications la ON c.customer_id = la.customer_id
JOIN loans l ON la.application_id = l.application_id
LEFT JOIN repayments r ON l.loan_id = r.loan_id
GROUP BY
    c.customer_id, c.credit_score, c.annual_income_gbp,
    c.employment_status, la.risk_tier, l.loan_amount, l.apr, l.status
HAVING MAX(r.days_past_due) > 0 OR l.status IN ('defaulted', 'charged_off')
ORDER BY max_dpd DESC NULLS LAST;


-- -------------------------------------------------------
-- Q5: Payment behaviour — on-time vs late vs missed
-- -------------------------------------------------------
SELECT
    CASE
        WHEN days_past_due = 0         THEN 'On Time'
        WHEN days_past_due BETWEEN 1 AND 29  THEN '1-29 DPD'
        WHEN days_past_due BETWEEN 30 AND 59 THEN '30-59 DPD'
        WHEN days_past_due BETWEEN 60 AND 89 THEN '60-89 DPD'
        WHEN days_past_due >= 90       THEN '90+ DPD (Default Territory)'
    END                          AS dpd_bucket,
    COUNT(*)                     AS repayment_count,
    ROUND(SUM(amount_due), 2)    AS total_amount_due,
    ROUND(SUM(amount_paid), 2)   AS total_amount_paid,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS pct_of_all_repayments
FROM repayments
GROUP BY 1
ORDER BY
    CASE dpd_bucket
        WHEN 'On Time' THEN 1
        WHEN '1-29 DPD' THEN 2
        WHEN '30-59 DPD' THEN 3
        WHEN '60-89 DPD' THEN 4
        ELSE 5
    END;
