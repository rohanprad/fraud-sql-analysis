-- ============================================
-- 06_evaluation.sql
-- Purpose: If the fraud team reviews the riskiest X% of transactions,
--          how much fraud do they catch?
-- Dataset: IEEE-CIS Fraud Detection
-- ============================================
--
-- For every possible score cut-off ("review everything scoring >= N"):
--   pct_reviewed  = share of transactions the team would check
--   pct_caught    = share of all fraud inside that group  (capture rate)
--   precision     = share of reviewed transactions that are fraud
--   lift          = precision / overall fraud rate
--
-- Calculated separately for TRAIN (rules built here) and TEST (unseen days).
-- If TEST is close to TRAIN, the score generalises and isn't overfitted.

CREATE OR REPLACE TABLE `glass-timing-490318-d7.fraud_work.capture_curve` AS
WITH by_score AS (
  SELECT split, risk_score,
         COUNT(*) AS txns, SUM(isFraud) AS fraud,
         SUM(IF(isFraud = 1, TransactionAmt, 0)) AS fraud_amt
  FROM `glass-timing-490318-d7.fraud_work.txn_scored`
  GROUP BY split, risk_score
),
cum AS (
  SELECT
    split,
    risk_score AS cutoff,
    SUM(txns)      OVER w AS reviewed_txns,
    SUM(fraud)     OVER w AS caught_fraud,
    SUM(fraud_amt) OVER w AS caught_fraud_amt,
    SUM(txns)      OVER (PARTITION BY split) AS total_txns,
    SUM(fraud)     OVER (PARTITION BY split) AS total_fraud,
    SUM(fraud_amt) OVER (PARTITION BY split) AS total_fraud_amt
  FROM by_score
  WINDOW w AS (PARTITION BY split ORDER BY risk_score DESC
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
)
SELECT
  split, cutoff,
  reviewed_txns, caught_fraud,
  ROUND(reviewed_txns / total_txns * 100, 2)          AS pct_reviewed,
  ROUND(caught_fraud / total_fraud * 100, 1)          AS pct_caught,
  ROUND(caught_fraud_amt / total_fraud_amt * 100, 1)  AS pct_fraud_value_caught,
  ROUND(caught_fraud / reviewed_txns * 100, 1)        AS precision_pct,
  ROUND((caught_fraud / reviewed_txns) / (total_fraud / total_txns), 1) AS lift
FROM cum;

SELECT * FROM `glass-timing-490318-d7.fraud_work.capture_curve`
WHERE pct_reviewed <= 40
ORDER BY split DESC, cutoff DESC;
