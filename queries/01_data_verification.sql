-- ============================================
-- 01_data_verification.sql
-- Purpose: Verify data loaded correctly
-- Dataset: IEEE-CIS Fraud Detection
-- ============================================

-- 1. Row counts for both tables
SELECT 'transactions' AS table_name, COUNT(*) AS row_count
FROM `fraud_analysis.transactions`
UNION ALL
SELECT 'identity' AS table_name, COUNT(*) AS row_count
FROM `your-project-id.fraud_analysis.identity`;

-- 2. Column names and data types - transactions
SELECT column_name, data_type
FROM `fraud_analysis`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'transactions'
ORDER BY ordinal_position;

-- 3. Column names and data types - identity
SELECT column_name, data_type
FROM `fraud_analysis`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'identity'
ORDER BY ordinal_position;

-- 4. Preview transactions
SELECT * FROM `fraud_analysis.transactions`
LIMIT 5;

-- 5. Preview identity
SELECT * FROM `fraud_analysis.identity`
LIMIT 5;
