-- ============================================
-- 03_fraud_patterns.sql
-- Purpose: Fraud Pattern Analysis
-- Dataset: IEEE-CIS Fraud Detection
-- ============================================

-- 1. Card testing detection
-- Identifies cards with small transactions followed by larger ones
-- Signal: sub-$10 charge to verify card, then larger fraudulent purchase
WITH card_transactions AS (
  SELECT
    card1,
    TransactionID,
    TransactionAmt,
    TransactionDT,
    isFraud,
    LAG(TransactionAmt) OVER (
      PARTITION BY card1 ORDER BY TransactionDT
    ) AS prev_txn_amt,
    LAG(isFraud) OVER (
      PARTITION BY card1 ORDER BY TransactionDT
    ) AS prev_txn_fraud
  FROM `fraud_analysis.transactions`
)
SELECT
  card1,
  COUNT(*) AS total_txns,
  SUM(isFraud) AS fraud_txns,
  ROUND(AVG(isFraud) * 100, 2) AS fraud_rate_pct,
  COUNTIF(prev_txn_amt < 10 AND TransactionAmt > 100) AS suspected_test_then_real,
  ROUND(AVG(TransactionAmt), 2) AS avg_txn_amt
FROM card_transactions
WHERE prev_txn_amt IS NOT NULL
GROUP BY card1
HAVING suspected_test_then_real > 0
ORDER BY suspected_test_then_real DESC
LIMIT 50;

-- ============================================

-- 2. Time-based fraud patterns
-- Breaks transactions into hours of the day using modulo arithmetic
-- TransactionDT is seconds from a reference point, not a real timestamp
WITH hourly AS (
  SELECT
    FLOOR(MOD(TransactionDT, 86400) / 3600) AS hour_of_day,
    COUNT(*) AS total_txns,
    SUM(isFraud) AS fraud_txns,
    ROUND(AVG(isFraud) * 100, 2) AS fraud_rate_pct
  FROM `fraud_analysis.transactions`
  GROUP BY hour_of_day
)
SELECT
  hour_of_day,
  total_txns,
  fraud_txns,
  fraud_rate_pct,
  ROUND(AVG(fraud_rate_pct) OVER (
    ORDER BY hour_of_day
    ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
  ), 2) AS smoothed_fraud_rate
FROM hourly
ORDER BY hour_of_day;

-- ============================================

-- 3. Repeat fraud cards
-- Finds cards appearing in 2+ fraudulent transactions
-- Indicates stolen card numbers being reused or repeat victims
WITH card_summary AS (
  SELECT
    card1,
    card4 AS card_network,
    card6 AS card_type,
    COUNT(*) AS total_txns,
    SUM(isFraud) AS fraud_txns,
    ROUND(AVG(isFraud) * 100, 2) AS fraud_rate_pct,
    ROUND(SUM(TransactionAmt), 2) AS total_amt,
    ROUND(AVG(TransactionAmt), 2) AS avg_txn_amt,
    MIN(TransactionDT) AS first_seen,
    MAX(TransactionDT) AS last_seen
  FROM `fraud_analysis.transactions`
  GROUP BY card1, card4, card6
  HAVING fraud_txns >= 2
)
SELECT
  *,
  RANK() OVER (ORDER BY fraud_txns DESC) AS fraud_rank,
  ROUND((last_seen - first_seen) / 3600, 1) AS active_hours
FROM card_summary
ORDER BY fraud_txns DESC
LIMIT 50;

-- ============================================

-- 4. High risk email domains cross-referenced with product category
-- Tests whether the two biggest risk signals from EDA overlap
-- High risk domains: mail.com, outlook.es, aim.com, outlook.com, hotmail.com
SELECT
  P_emaildomain AS email_domain,
  ProductCD,
  COUNT(*) AS total_txns,
  SUM(isFraud) AS fraud_txns,
  ROUND(AVG(isFraud) * 100, 2) AS fraud_rate_pct,
  ROUND(AVG(TransactionAmt), 2) AS avg_txn_amt
FROM `fraud_analysis.transactions`
WHERE P_emaildomain IN (
  'mail.com', 'outlook.es', 'aim.com', 'outlook.com', 'hotmail.com'
)
GROUP BY P_emaildomain, ProductCD
HAVING COUNT(*) > 10
ORDER BY fraud_rate_pct DESC;

-- ============================================

-- 5. Mobile device fraud by email domain
-- Combines two high risk signals to test if they compound each other
-- Only ~24% of transactions have device data so results are a subset
SELECT
  t.P_emaildomain AS email_domain,
  i.DeviceType,
  COUNT(*) AS total_txns,
  SUM(t.isFraud) AS fraud_txns,
  ROUND(AVG(t.isFraud) * 100, 2) AS fraud_rate_pct,
  ROUND(AVG(t.TransactionAmt), 2) AS avg_txn_amt
FROM `fraud_analysis.transactions` t
LEFT JOIN `fraud_analysis.identity` i
  ON t.TransactionID = i.TransactionID
WHERE i.DeviceType IS NOT NULL
  AND t.P_emaildomain IS NOT NULL
GROUP BY t.P_emaildomain, i.DeviceType
HAVING COUNT(*) > 50
ORDER BY fraud_rate_pct DESC
LIMIT 20;

-- ============================================

-- 6. Running cumulative fraud rate over time
-- Shows how fraud evolved across the dataset timeline
-- Useful for identifying fraud spikes or coordinated campaigns
WITH daily AS (
  SELECT
    FLOOR(TransactionDT / 86400) AS day_number,
    COUNT(*) AS total_txns,
    SUM(isFraud) AS fraud_txns,
    ROUND(AVG(isFraud) * 100, 2) AS daily_fraud_rate_pct
  FROM `fraud_analysis.transactions`
  GROUP BY day_number
)
SELECT
  day_number,
  total_txns,
  fraud_txns,
  daily_fraud_rate_pct,
  SUM(fraud_txns) OVER (ORDER BY day_number) AS cumulative_fraud,
  SUM(total_txns) OVER (ORDER BY day_number) AS cumulative_txns,
  ROUND(
    SUM(fraud_txns) OVER (ORDER BY day_number) * 100.0 /
    SUM(total_txns) OVER (ORDER BY day_number), 2
  ) AS cumulative_fraud_rate_pct
FROM daily
ORDER BY day_number;
