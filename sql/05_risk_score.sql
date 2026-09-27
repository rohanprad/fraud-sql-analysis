-- ============================================
-- 05_risk_score.sql
-- Purpose: Turn the warning signs into a simple points-based risk score
-- Dataset: IEEE-CIS Fraud Detection
-- ============================================
--
-- Points come from how risky each group was in the TRAIN period (lift from
-- 04_fraud_patterns.sql):
--   lift >= 2.5  -> +3   (e.g. product C, mobile device)
--   lift >= 1.5  -> +2   (e.g. credit card, overnight)
--   lift >= 1.2  -> +1   (e.g. amount $200-1000)
--   lift <  0.8  -> -1   (clearly safer, e.g. debit card, product W)
--   otherwise    ->  0
-- Groups with fewer than 500 train transactions got no rate (too noisy), so
-- they score 0. That includes mail.com and card testing: real signals, but
-- too rare to trust yet.
--
-- The score = the sum of points across all signals. Simple enough to explain
-- on a whiteboard and to run as rules in a fraud system.

CREATE OR REPLACE TABLE `glass-timing-490318-d7.fraud_work.signal_points` AS
SELECT
  signal, value, lift, fraud_rate_pct, train_txns,
  CASE
    WHEN lift >= 2.5 THEN 3
    WHEN lift >= 1.5 THEN 2
    WHEN lift >= 1.2 THEN 1
    WHEN lift <  0.8 THEN -1
    ELSE 0
  END AS points
FROM `glass-timing-490318-d7.fraud_work.signal_rates`;

CREATE OR REPLACE TABLE `glass-timing-490318-d7.fraud_work.txn_scored` AS
WITH vals AS (
  -- Each transaction's value for every signal, labelled the same way as in 04
  SELECT
    TransactionID, split, isFraud, TransactionAmt,
    IF(is_overnight, 'overnight', 'daytime')                   AS v_time,
    ProductCD                                                  AS v_product,
    IFNULL(card6, 'unknown')                                   AS v_card_type,
    amount_band                                                AS v_amount,
    IFNULL(DeviceType, 'no device data')                       AS v_device,
    IFNULL(P_emaildomain, 'missing')                           AS v_email,
    CASE WHEN txns_prev_24h IS NULL THEN NULL
         WHEN txns_prev_24h = 0 THEN '0 previous'
         WHEN txns_prev_24h <= 2 THEN '1-2 previous'
         WHEN txns_prev_24h <= 5 THEN '3-5 previous'
         ELSE '6+ previous' END                                AS v_velocity
  FROM `glass-timing-490318-d7.fraud_work.txn_features`
),
p AS (SELECT signal, value, points FROM `glass-timing-490318-d7.fraud_work.signal_points`)
SELECT
  v.TransactionID, v.split, v.isFraud, v.TransactionAmt,
  IFNULL(pt.points, 0) AS pts_time,
  IFNULL(pp.points, 0) AS pts_product,
  IFNULL(pc.points, 0) AS pts_card_type,
  IFNULL(pa.points, 0) AS pts_amount,
  IFNULL(pd.points, 0) AS pts_device,
  IFNULL(pe.points, 0) AS pts_email,
  IFNULL(pv.points, 0) AS pts_velocity,
    IFNULL(pt.points, 0) + IFNULL(pp.points, 0) + IFNULL(pc.points, 0) + IFNULL(pa.points, 0)
  + IFNULL(pd.points, 0) + IFNULL(pe.points, 0) + IFNULL(pv.points, 0) AS risk_score
FROM vals v
LEFT JOIN p pt ON pt.signal = 'time'         AND pt.value = v.v_time
LEFT JOIN p pp ON pp.signal = 'product'      AND pp.value = v.v_product
LEFT JOIN p pc ON pc.signal = 'card_type'    AND pc.value = v.v_card_type
LEFT JOIN p pa ON pa.signal = 'amount'       AND pa.value = v.v_amount
LEFT JOIN p pd ON pd.signal = 'device'       AND pd.value = v.v_device
LEFT JOIN p pe ON pe.signal = 'email_domain' AND pe.value = v.v_email
LEFT JOIN p pv ON pv.signal = 'velocity_24h' AND pv.value = v.v_velocity;

-- Points table, for the README
SELECT signal, value, points, lift, fraud_rate_pct, train_txns
FROM `glass-timing-490318-d7.fraud_work.signal_points`
WHERE points != 0
ORDER BY points DESC, lift DESC;
