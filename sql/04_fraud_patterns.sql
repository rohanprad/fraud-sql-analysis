-- ============================================
-- 04_fraud_patterns.sql
-- Purpose: Fraud warning signs, measured at ACCOUNT level
-- Dataset: IEEE-CIS Fraud Detection
-- ============================================
--
-- Rewrite of the first version, which grouped by card1 (a shared attribute,
-- not a card) and read the dataset's offset clock as real time.
--
-- Every rate here uses the TRAIN period only (days 1-127). These signals feed
-- the risk score, which is then tested on days 128-182 it has never seen.
--
-- Deliberately NOT used: "the account's previous transaction was fraud".
-- Fraud is only confirmed weeks later (chargebacks), so a real-time system
-- wouldn't know that yet. Using it would make the score look better than it
-- could ever be in practice ("leakage").

-- ============================================
-- 1. Features for every transaction
-- ============================================
CREATE OR REPLACE TABLE `glass-timing-490318-d7.fraud_work.txn_features` AS
WITH quiet_hours AS (
  -- "Overnight" = dataset hours where TRAIN volume is under 25% of the
  -- busiest hour. Real shopping is quietest in the middle of the night.
  SELECT hour_dataset
  FROM (
    SELECT hour_dataset, COUNT(*) AS n, MAX(COUNT(*)) OVER () AS peak
    FROM `glass-timing-490318-d7.fraud_work.txn_enriched`
    WHERE split = 'train'
    GROUP BY hour_dataset
  )
  WHERE n < 0.25 * peak
),
seq AS (
  SELECT
    e.*,
    -- Previous transaction BY THE SAME ACCOUNT (not the same card1)
    LAG(TransactionAmt) OVER w AS prev_amt,
    TransactionDT - LAG(TransactionDT) OVER w AS secs_since_prev,
    -- Velocity: how many times this account transacted in the previous 24h
    COUNT(*) OVER (
      PARTITION BY account_id ORDER BY TransactionDT
      RANGE BETWEEN 86400 PRECEDING AND 1 PRECEDING
    ) AS txns_prev_24h
  FROM `glass-timing-490318-d7.fraud_work.txn_enriched` e
  WINDOW w AS (PARTITION BY account_id ORDER BY TransactionDT)
)
SELECT
  s.* EXCEPT (prev_amt, secs_since_prev, txns_prev_24h),
  s.hour_dataset IN (SELECT hour_dataset FROM quiet_hours)          AS is_overnight,
  CASE
    WHEN TransactionAmt < 10   THEN '1_<$10'
    WHEN TransactionAmt < 50   THEN '2_$10-50'
    WHEN TransactionAmt < 200  THEN '3_$50-200'
    WHEN TransactionAmt < 1000 THEN '4_$200-1000'
    ELSE                            '5_$1000+'
  END                                                               AS amount_band,
  -- Card testing: a sub-$10 purchase by the same account in the previous 24h
  IF(account_id_partial, NULL,
     prev_amt < 10 AND secs_since_prev <= 86400)                    AS after_small_test,
  -- Velocity is only meaningful when the account ID is complete
  IF(account_id_partial, NULL, txns_prev_24h)                       AS txns_prev_24h
FROM seq s;

-- ============================================
-- 2. How risky is each warning sign? (train only)
-- lift = fraud rate for this group / overall train fraud rate
-- ============================================
CREATE OR REPLACE TABLE `glass-timing-490318-d7.fraud_work.signal_rates` AS
WITH f AS (
  SELECT * FROM `glass-timing-490318-d7.fraud_work.txn_features` WHERE split = 'train'
),
base AS (SELECT AVG(isFraud) AS rate FROM f),
g AS (
  SELECT 'time' AS signal, IF(is_overnight, 'overnight', 'daytime') AS value, isFraud FROM f
  UNION ALL SELECT 'product', ProductCD, isFraud FROM f
  UNION ALL SELECT 'card_type', IFNULL(card6, 'unknown'), isFraud FROM f
  UNION ALL SELECT 'amount', amount_band, isFraud FROM f
  UNION ALL SELECT 'device', IFNULL(DeviceType, 'no device data'), isFraud FROM f
  UNION ALL SELECT 'email_domain', IFNULL(P_emaildomain, 'missing'), isFraud FROM f
  UNION ALL SELECT 'card_testing', IF(after_small_test, 'small test in prev 24h', 'no'), isFraud
            FROM f WHERE after_small_test IS NOT NULL
  UNION ALL SELECT 'velocity_24h',
            CASE WHEN txns_prev_24h = 0 THEN '0 previous'
                 WHEN txns_prev_24h <= 2 THEN '1-2 previous'
                 WHEN txns_prev_24h <= 5 THEN '3-5 previous'
                 ELSE '6+ previous' END, isFraud
            FROM f WHERE txns_prev_24h IS NOT NULL
)
SELECT
  signal, value,
  COUNT(*)                                   AS train_txns,
  SUM(isFraud)                               AS train_fraud,
  ROUND(AVG(isFraud) * 100, 2)               AS fraud_rate_pct,
  ROUND(AVG(isFraud) / (SELECT rate FROM base), 2) AS lift
FROM g
GROUP BY signal, value
HAVING COUNT(*) >= 500        -- ignore tiny groups: their rates are mostly noise
ORDER BY signal, lift DESC;

-- ============================================
-- 3. Repeat fraud, done properly: once an account's fraud starts, how long
--    does it keep transacting? (all days; descriptive, not used in the score)
-- ============================================
WITH acct AS (
  SELECT
    account_id,
    COUNT(*) AS txns,
    SUM(isFraud) AS fraud_txns,
    MIN(IF(isFraud = 1, TransactionDT, NULL)) AS first_fraud_dt,
    MAX(IF(isFraud = 1, TransactionDT, NULL)) AS last_fraud_dt,
    SUM(IF(isFraud = 1, TransactionAmt, 0)) AS fraud_amt
  FROM `glass-timing-490318-d7.fraud_work.txn_features`
  WHERE NOT account_id_partial
  GROUP BY account_id
  HAVING SUM(isFraud) > 0
)
SELECT
  COUNT(*)                                                        AS fraud_accounts,
  COUNTIF(fraud_txns >= 2)                                        AS repeat_fraud_accounts,
  ROUND(COUNTIF(fraud_txns >= 2) / COUNT(*) * 100, 1)             AS pct_repeat,
  SUM(fraud_txns)                                                 AS fraud_txns_total,
  SUM(fraud_txns - 1)                                             AS fraud_txns_after_first,
  ROUND(SUM(fraud_txns - 1) / SUM(fraud_txns) * 100, 1)           AS pct_fraud_after_first,
  APPROX_QUANTILES(ROUND((last_fraud_dt - first_fraud_dt) / 86400, 1), 4) AS days_first_to_last_fraud_quartiles
FROM acct;
