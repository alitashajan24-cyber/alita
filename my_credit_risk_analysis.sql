-- My Credit Risk Analysis
-- Using the Credit_Risk dataset (200 customers)
-- Written by Alita S.


-- First things first, let me just see what the data looks like
SELECT *
FROM Credit_Risk
LIMIT 10;


-- How many customers do we have in each risk group?
SELECT
    RiskCategory,
    COUNT(*) AS total
FROM Credit_Risk
GROUP BY RiskCategory;


-- What's the average credit score for each risk group?
-- I'd expect High risk to have lower scores
SELECT
    RiskCategory,
    ROUND(AVG(CreditScoreAtLoan), 0) AS avg_credit_score
FROM Credit_Risk
GROUP BY RiskCategory
ORDER BY avg_credit_score DESC;


-- How likely is each group to default?
SELECT
    RiskCategory,
    ROUND(AVG(DefaultProbability) * 100, 1) AS avg_default_chance_pct
FROM Credit_Risk
GROUP BY RiskCategory
ORDER BY avg_default_chance_pct DESC;


-- What protection do customers have?
-- Collateral, Insurance, Co-signer, or nothing at all
SELECT
    RiskMitigation,
    COUNT(*) AS total
FROM Credit_Risk
GROUP BY RiskMitigation
ORDER BY total DESC;


-- Does having protection actually reduce default risk?
SELECT
    RiskMitigation,
    ROUND(AVG(DefaultProbability) * 100, 1) AS avg_default_chance_pct
FROM Credit_Risk
GROUP BY RiskMitigation
ORDER BY avg_default_chance_pct ASC;


-- Let me group customers into credit score buckets
-- to see the shape of the portfolio
SELECT
    CASE
        WHEN CreditScoreAtLoan >= 750 THEN 'Excellent'
        WHEN CreditScoreAtLoan >= 650 THEN 'Good'
        WHEN CreditScoreAtLoan >= 550 THEN 'Fair'
        ELSE 'Poor'
    END AS score_band,
    COUNT(*) AS total_customers,
    ROUND(AVG(DefaultProbability) * 100, 1) AS avg_default_chance_pct
FROM Credit_Risk
GROUP BY score_band
ORDER BY avg_default_chance_pct DESC;


-- Who are the most at-risk customers?
-- High default chance AND no protection whatsoever
SELECT
    CustomerID,
    CreditScoreAtLoan,
    RiskCategory,
    ROUND(DefaultProbability * 100, 1) AS default_chance_pct
FROM Credit_Risk
WHERE RiskMitigation = 'None'
  AND DefaultProbability > 0.20
ORDER BY DefaultProbability DESC;


-- Something interesting I noticed --
-- Some customers are labelled High risk but have great credit scores
-- This seems wrong and worth flagging
SELECT
    CustomerID,
    CreditScoreAtLoan,
    RiskCategory,
    ROUND(DefaultProbability * 100, 1) AS default_chance_pct
FROM Credit_Risk
WHERE RiskCategory = 'High'
  AND CreditScoreAtLoan > 750
ORDER BY CreditScoreAtLoan DESC;
