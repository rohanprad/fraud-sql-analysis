-- ============================================
-- 03_accounts.sql
-- Purpose: One tidy table to build everything else on, with an
--          approximate ACCOUNT ID for every transaction
-- Dataset: IEEE-CIS Fraud Detection
-- ============================================
--
-- Why: card1 is NOT a card. It's an anonymised card attribute shared by many
-- customers (card1 = 15885 alone covers ~709 accounts). Analysing "per card1"
-- adds hundreds of people together.
--
-- Account ID = card1 + billing region (addr1) + the day the account started.
--   D1 = days since the card/account was first used, so
--   (transaction day - D1) is the account's start day: it stays the same
--   for every transaction by the same account.
--
-- Time: TransactionDT is seconds from an unknown start point, not a real
-- timestamp. hour_dataset is the hour on the dataset's own clock. Volume is
-- lowest at dataset hours 6-10, which is really the middle of the night.
--
-- Train/test: days 1-127 (first ~70%) build the rules; days 128-182 test them.
--
-- Output goes to the fraud_work dataset: the project runs in the free BigQuery
-- sandbox, where new tables must expire within 60 days. The source data in
-- fraud_analysis is untouched; rerun these files to rebuild fraud_work.

CREATE OR REPLACE TABLE `glass-timing-490318-d7.fraud_work.txn_enriched` AS
SELECT
  t.TransactionID,
  t.isFraud,
  t.TransactionAmt,
  t.ProductCD,
  t.card1,
  t.card4,
  t.card6,
  t.P_emaildomain,
  i.DeviceType,
  t.TransactionDT,
  CAST(FLOOR(t.TransactionDT / 86400) AS INT64)                  AS day,
  CAST(FLOOR(MOD(t.TransactionDT, 86400) / 3600) AS INT64)       AS hour_dataset,
  CONCAT(
    CAST(t.card1 AS STRING), '_',
    IFNULL(CAST(CAST(t.addr1 AS INT64) AS STRING), 'na'), '_',
    IFNULL(CAST(CAST(FLOOR(t.TransactionDT / 86400) - t.D1 AS INT64) AS STRING), 'na')
  )                                                              AS account_id,
  (t.addr1 IS NULL OR t.D1 IS NULL)                              AS account_id_partial,
  IF(FLOOR(t.TransactionDT / 86400) <= 127, 'train', 'test')     AS split
FROM `glass-timing-490318-d7.fraud_analysis.transactions` t
LEFT JOIN `glass-timing-490318-d7.fraud_analysis.identity` i
  ON t.TransactionID = i.TransactionID;

-- ============================================
-- Sanity check: does account_id behave like a real account?
-- In this dataset, once an account is caught, its later transactions are
-- labelled fraud too. So a good account ID should give accounts that are
-- (almost) all-fraud or all-legit ("pure"). card1 groups should be far messier.
-- ============================================
WITH by_account AS (
  SELECT account_id AS grp, COUNT(*) AS n, SUM(isFraud) AS f
  FROM `glass-timing-490318-d7.fraud_work.txn_enriched`
  WHERE NOT account_id_partial
  GROUP BY account_id
),
by_card1 AS (
  SELECT CAST(card1 AS STRING) AS grp, COUNT(*) AS n, SUM(isFraud) AS f
  FROM `glass-timing-490318-d7.fraud_work.txn_enriched`
  GROUP BY card1
)
SELECT
  'account_id' AS grouped_by,
  COUNT(*) AS n_groups,
  ROUND(AVG(n), 1) AS avg_txns_per_group,
  -- among groups with any fraud: share that are ALL fraud
  ROUND(COUNTIF(f = n AND f > 0) / NULLIF(COUNTIF(f > 0), 0) * 100, 1) AS pct_fraud_groups_all_fraud,
  -- among groups with 2+ txns: share with a single label
  ROUND(COUNTIF(n >= 2 AND (f = 0 OR f = n)) / NULLIF(COUNTIF(n >= 2), 0) * 100, 1) AS pct_multi_txn_groups_pure
FROM by_account
UNION ALL
SELECT
  'card1',
  COUNT(*),
  ROUND(AVG(n), 1),
  ROUND(COUNTIF(f = n AND f > 0) / NULLIF(COUNTIF(f > 0), 0) * 100, 1),
  ROUND(COUNTIF(n >= 2 AND (f = 0 OR f = n)) / NULLIF(COUNTIF(n >= 2), 0) * 100, 1)
FROM by_card1;
