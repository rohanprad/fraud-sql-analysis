-- ============================================
-- 07_expected_loss.sql
-- Purpose: Rank transactions by MONEY at risk, not just chance of fraud
-- Dataset: IEEE-CIS Fraud Detection
-- ============================================
--
-- The risk score (05) finds fraud, but mostly small purchases: fraud it catches
-- averages $58, fraud it misses averages $182. A fraud team cares about money.
--
--   expected loss = chance of fraud x transaction amount
--
-- A $500 purchase with a 20% chance of fraud ($100 at risk) is checked before
-- a $10 purchase with the same chance ($2 at risk).
--
-- "Chance of fraud" for each score comes from the TRAIN period: the share of
-- transactions at that score that were fraud. Scores of 12 and above are rare
-- (13-409 transactions each), so they're grouped into one "12+" band. Any
-- remaining small groups are pulled slightly towards the overall average
-- (smoothing, weight = 200 transactions) so no score can claim an extreme rate
-- from a handful of cases.

-- 1. Chance of fraud for each score (train only)
CREATE OR REPLACE TABLE `glass-timing-490318-d7.fraud_work.score_calibration` AS
WITH base AS (
  SELECT AVG(isFraud) AS rate
  FROM `glass-timing-490318-d7.fraud_work.txn_scored` WHERE split = 'train'
)
SELECT
  LEAST(risk_score, 12) AS score_band,   -- 12 = "12 or more"
  COUNT(*) AS train_txns,
  SUM(isFraud) AS train_fraud,
  ROUND(AVG(isFraud) * 100, 2) AS raw_fraud_rate_pct,
  (SUM(isFraud) + 200 * (SELECT rate FROM base)) / (COUNT(*) + 200) AS p_fraud
FROM `glass-timing-490318-d7.fraud_work.txn_scored`
WHERE split = 'train'
GROUP BY score_band;

-- 2. Expected loss for every transaction
CREATE OR REPLACE TABLE `glass-timing-490318-d7.fraud_work.txn_expected_loss` AS
WITH base AS (
  SELECT AVG(isFraud) AS rate
  FROM `glass-timing-490318-d7.fraud_work.txn_scored` WHERE split = 'train'
),
p AS (
  -- A score never seen in train (possible in test) falls back to the average rate
  SELECT s.*, IFNULL(c.p_fraud, (SELECT rate FROM base)) AS p_fraud
  FROM `glass-timing-490318-d7.fraud_work.txn_scored` s
  LEFT JOIN `glass-timing-490318-d7.fraud_work.score_calibration` c
    ON c.score_band = LEAST(s.risk_score, 12)
)
SELECT *, p_fraud * TransactionAmt AS expected_loss
FROM p;

-- 3. Head-to-head on the TEST days: three ways to fill the review queue
--    risk_score     -> highest score first            (catch the most frauds)
--    expected_loss  -> most money at risk first
--    biggest_amount -> largest purchases first        (simplest money rule)
-- Ties are broken at random (a hash of the ID) so no method gets lucky.
CREATE OR REPLACE TABLE `glass-timing-490318-d7.fraud_work.capture_compare` AS
WITH t AS (
  SELECT * FROM `glass-timing-490318-d7.fraud_work.txn_expected_loss` WHERE split = 'test'
),
ranked AS (
  SELECT 'risk_score' AS method, isFraud, TransactionAmt,
         ROW_NUMBER() OVER (ORDER BY risk_score DESC, FARM_FINGERPRINT(CAST(TransactionID AS STRING))) AS rn
  FROM t
  UNION ALL
  SELECT 'expected_loss', isFraud, TransactionAmt,
         ROW_NUMBER() OVER (ORDER BY expected_loss DESC, FARM_FINGERPRINT(CAST(TransactionID AS STRING)))
  FROM t
  UNION ALL
  SELECT 'biggest_amount', isFraud, TransactionAmt,
         ROW_NUMBER() OVER (ORDER BY TransactionAmt DESC, FARM_FINGERPRINT(CAST(TransactionID AS STRING)))
  FROM t
),
totals AS (
  SELECT COUNT(*) AS n, SUM(isFraud) AS fraud, SUM(IF(isFraud = 1, TransactionAmt, 0)) AS fraud_amt FROM t
),
steps AS (
  -- review levels from 0.5% to 30% in 0.5% steps
  SELECT step / 2 AS pct_reviewed FROM UNNEST(GENERATE_ARRAY(1, 60)) AS step
)
SELECT
  r.method,
  s.pct_reviewed,
  ROUND(SUM(r.isFraud) / ANY_VALUE(tot.fraud) * 100, 1)                                AS pct_fraud_caught,
  ROUND(SUM(IF(r.isFraud = 1, r.TransactionAmt, 0)) / ANY_VALUE(tot.fraud_amt) * 100, 1) AS pct_fraud_value_caught,
  ROUND(SUM(r.isFraud) / COUNT(*) * 100, 1)                                            AS precision_pct,
  ROUND(SUM(IF(r.isFraud = 1, r.TransactionAmt, 0)))                                   AS fraud_value_caught
FROM steps s
CROSS JOIN totals tot
JOIN ranked r ON r.rn <= s.pct_reviewed / 100 * tot.n
GROUP BY r.method, s.pct_reviewed;

-- 4. Summary at the review levels we care about
SELECT *
FROM `glass-timing-490318-d7.fraud_work.capture_compare`
WHERE pct_reviewed IN (1, 2, 4, 5, 7, 10, 15, 20)
ORDER BY pct_reviewed, method;
