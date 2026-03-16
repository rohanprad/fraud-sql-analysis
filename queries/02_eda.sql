-- ============================================
-- 02_eda.sql
-- Purpose: Exploratory Data Analysis
-- Dataset: IEEE-CIS Fraud Detection
-- ============================================

-- 1. Fraud rate overview
SELECT
  isFraud,
  COUNT(*) AS transaction_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_total
FROM `fraud_analysis.transactions`
GROUP BY isFraud;

-- 2. Transaction amount distribution
SELECT
  CASE
    WHEN TransactionAmt < 10   THEN '1_Under $10'
    WHEN TransactionAmt < 50   THEN '2_$10-$50'
    WHEN TransactionAmt < 200  THEN '3_$50-$200'
    WHEN TransactionAmt < 1000 THEN '4_$200-$1000'
    ELSE                            '5_Over $1000'
  END AS amount_bucket,
  COUNT(*) AS txn_count,
  SUM(isFraud) AS fraud_count,
  ROUND(AVG(isFraud) * 100, 2) AS fraud_rate_pct
FROM `fraud_analysis.transactions`
GROUP BY amount_bucket
ORDER BY amount_bucket;

-- 3. Fraud by card network and type
SELECT
  card4 AS card_network,
  card6 AS card_type,
  COUNT(*) AS total_txns,
  SUM(isFraud) AS fraud_txns,
  ROUND(AVG(isFraud) * 100, 2) AS fraud_rate_pct
FROM `fraud_analysis.transactions`
WHERE card4 IS NOT NULL
  AND card6 IS NOT NULL
GROUP BY card4, card6
ORDER BY fraud_rate_pct DESC;

-- 4. Fraud by product category
SELECT
  ProductCD,
  COUNT(*) AS total_txns,
  SUM(isFraud) AS fraud_txns,
  ROUND(AVG(isFraud) * 100, 2) AS fraud_rate_pct,
  ROUND(AVG(TransactionAmt), 2) AS avg_txn_amt
FROM `fraud_analysis.transactions`
GROUP BY ProductCD
ORDER BY fraud_rate_pct DESC;

-- 5. Fraud by email domain
SELECT
  P_emaildomain AS email_domain,
  COUNT(*) AS total_txns,
  SUM(isFraud) AS fraud_txns,
  ROUND(AVG(isFraud) * 100, 2) AS fraud_rate_pct,
  ROUND(AVG(TransactionAmt), 2) AS avg_txn_amt
FROM `fraud_analysis.transactions`
WHERE P_emaildomain IS NOT NULL
GROUP BY P_emaildomain
HAVING COUNT(*) > 100
ORDER BY fraud_rate_pct DESC
LIMIT 20;

-- 6. Fraud by device type
SELECT
  i.DeviceType,
  COUNT(*) AS total_txns,
  SUM(t.isFraud) AS fraud_txns,
  ROUND(AVG(t.isFraud) * 100, 2) AS fraud_rate_pct,
  ROUND(AVG(t.TransactionAmt), 2) AS avg_txn_amt
FROM `fraud_analysis.transactions` t
LEFT JOIN `fraud_analysis.identity` i
  ON t.TransactionID = i.TransactionID
WHERE i.DeviceType IS NOT NULL
GROUP BY i.DeviceType
ORDER BY fraud_rate_pct DESC;

-- 7. Null check across key columns
SELECT
  COUNTIF(TransactionID IS NULL)   AS missing_id,
  COUNTIF(TransactionAmt IS NULL)  AS missing_amt,
  COUNTIF(isFraud IS NULL)         AS missing_label,
  COUNTIF(card4 IS NULL)           AS missing_card4,
  COUNTIF(card6 IS NULL)           AS missing_card6,
  COUNTIF(P_emaildomain IS NULL)   AS missing_email,
  COUNTIF(ProductCD IS NULL)       AS missing_product
FROM `fraud_analysis.transactions`;
