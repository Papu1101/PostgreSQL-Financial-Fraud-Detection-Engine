CREATE TABLE staging_transactions (
    transaction_id       TEXT,
    timestamp            TEXT,
    account_id           TEXT,
    amount               NUMERIC(15,2),
    currency             TEXT,
    merchant_category    TEXT,
    location_country     TEXT,
    device_id            TEXT,
    ip_address           INET,
    time_since_last_txn  NUMERIC(12,2),
    is_high_risk_ip      BOOLEAN,
    is_fraud             INTEGER
);

SELECT * FROM staging_transactions LIMIT 10;

SELECT COUNT(*) AS total_rows
FROM staging_transactions;


SELECT
    COUNT(*) AS total_rows,
    COUNT(transaction_id) AS transaction_ids,
    COUNT(account_id) AS account_ids,
    COUNT(amount) AS amounts,
    COUNT(device_id) AS device_ids,
    COUNT(ip_address) AS ip_addresses,
    COUNT(is_fraud) AS fraud_labels
FROM staging_transactions;


CREATE TABLE transactions (
    transaction_id       TEXT PRIMARY KEY,
    transaction_timestamp TIMESTAMP NOT NULL,
    account_id           TEXT NOT NULL,
    amount               NUMERIC(15,2),
    currency             TEXT,
    merchant_category    TEXT,
    location_country     TEXT,
    device_id            TEXT,
    ip_address           INET,
    time_since_last_txn  NUMERIC(12,2),
    is_high_risk_ip      BOOLEAN,
    is_fraud             INTEGER
);


INSERT INTO transactions (
    transaction_id,
    transaction_timestamp,
    account_id,
    amount,
    currency,
    merchant_category,
    location_country,
    device_id,
    ip_address,
    time_since_last_txn,
    is_high_risk_ip,
    is_fraud
)
SELECT
    transaction_id,
    TO_TIMESTAMP(timestamp, 'DD-MM-YYYY HH24:MI')::TIMESTAMP,
    account_id,
    amount,
    currency,
    merchant_category,
    location_country,
    device_id,
    ip_address,
    time_since_last_txn,
    is_high_risk_ip,
    is_fraud
FROM staging_transactions;


SELECT
    transaction_id,
    transaction_timestamp
FROM transactions
ORDER BY transaction_timestamp
LIMIT 10;


SELECT
    MIN(transaction_timestamp) AS first_transaction,
    MAX(transaction_timestamp) AS last_transaction
FROM transactions;

SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'transactions'
ORDER BY ordinal_position;



SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT transaction_id) AS unique_transactions,
    COUNT(DISTINCT account_id) AS unique_accounts,
    COUNT(DISTINCT merchant_category) AS merchant_categories,
    COUNT(DISTINCT location_country) AS countries,
    COUNT(DISTINCT currency) AS currencies
FROM transactions;


----Checking Nulls---

SELECT
    COUNT(*) FILTER (WHERE transaction_id IS NULL) AS null_transaction_id,
    COUNT(*) FILTER (WHERE transaction_timestamp IS NULL) AS null_timestamp,
    COUNT(*) FILTER (WHERE account_id IS NULL) AS null_account_id,
    COUNT(*) FILTER (WHERE amount IS NULL) AS null_amount,
    COUNT(*) FILTER (WHERE currency IS NULL) AS null_currency,
    COUNT(*) FILTER (WHERE merchant_category IS NULL) AS null_merchant_category,
    COUNT(*) FILTER (WHERE location_country IS NULL) AS null_country,
    COUNT(*) FILTER (WHERE device_id IS NULL) AS null_device_id,
    COUNT(*) FILTER (WHERE ip_address IS NULL) AS null_ip,
    COUNT(*) FILTER (WHERE time_since_last_txn IS NULL) AS null_time_since_last_txn,
    COUNT(*) FILTER (WHERE is_high_risk_ip IS NULL) AS null_high_risk_ip,
    COUNT(*) FILTER (WHERE is_fraud IS NULL) AS null_fraud
FROM transactions;

--Fraud Distribution ---

SELECT
    is_fraud,
    COUNT(*) AS transaction_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM transactions
GROUP BY is_fraud
ORDER BY is_fraud;

---Transaction Amount Quantity ---

SELECT
    MIN(amount) AS minimum_amount,
    MAX(amount) AS maximum_amount,
    ROUND(AVG(amount), 2) AS average_amount,
    PERCENTILE_CONT(0.50)
          WITHIN GROUP (ORDER BY amount) AS median_amount
FROM transactions;

----Checking for Duplicates ----

SELECT
    transaction_id,
    COUNT(*) AS occurrence_count
FROM transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;
-----Exact Duplicates---
SELECT
    transaction_id,
    transaction_timestamp,
    account_id,
    amount,
    currency,
    merchant_category,
    location_country,
    device_id,
    ip_address,
    time_since_last_txn,
    is_high_risk_ip,
    is_fraud,
    COUNT(*) AS duplicate_count
FROM transactions
GROUP BY
    transaction_id,
    transaction_timestamp,
    account_id,
    amount,
    currency,
    merchant_category,
    location_country,
    device_id,
    ip_address,
    time_since_last_txn,
    is_high_risk_ip,
    is_fraud
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

--Duplicate Summary --

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT transaction_id) AS unique_transaction_ids,
    COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_transaction_ids
FROM transactions;

---Invalid values---

SELECT
    COUNT(*) AS invalid_amount_transactions
FROM transactions
WHERE amount <= 0;

SELECT *
FROM transactions
WHERE amount <= 0
ORDER BY amount;

--Fraud Flag---

SELECT
    is_fraud,
    COUNT(*) AS transaction_count
FROM transactions
GROUP BY is_fraud
ORDER BY is_fraud;

SELECT COUNT(*) AS invalid_fraud_flags
FROM transactions
WHERE is_fraud NOT IN (0, 1)
   OR is_fraud IS NULL;


--High-risk IP flag---

SELECT
    is_high_risk_ip,
    COUNT(*) AS transaction_count
FROM transactions
GROUP BY is_high_risk_ip
ORDER BY is_high_risk_ip;

---Time since previous transaction--

SELECT
    COUNT(*) AS invalid_velocity_values
FROM transactions
WHERE time_since_last_txn < 0;

SELECT
    transaction_id,
    account_id,
    transaction_timestamp,
    time_since_last_txn
FROM transactions
WHERE time_since_last_txn < 0
ORDER BY time_since_last_txn;

---Timestamp range---

SELECT
    MIN(transaction_timestamp) AS earliest_transaction,
    MAX(transaction_timestamp) AS latest_transaction,
    COUNT(*) FILTER (
        WHERE transaction_timestamp IS NULL
    ) AS null_timestamps
FROM transactions;

----Logical consistency----

SELECT
    COUNT(*) FILTER (
        WHERE is_high_risk_ip = TRUE
          AND ip_address IS NULL
    ) AS high_risk_ip_without_ip,
    COUNT(*) FILTER (
        WHERE device_id IS NULL
    ) AS missing_device_id,
    COUNT(*) FILTER (
        WHERE ip_address IS NULL
    ) AS missing_ip,
    COUNT(*) FILTER (
        WHERE device_id IS NULL
          AND is_fraud = 1
    ) AS fraud_with_missing_device,
    COUNT(*) FILTER (
        WHERE ip_address IS NULL
          AND is_fraud = 1
    ) AS fraud_with_missing_ip
FROM transactions;


SELECT
    is_high_risk_ip,
    COUNT(*) AS transaction_count
FROM transactions
GROUP BY is_high_risk_ip
ORDER BY is_high_risk_ip;


SELECT
    COUNT(*) FILTER (WHERE ip_address IS NULL) AS missing_ip,
    COUNT(*) FILTER (
        WHERE is_high_risk_ip = TRUE
        AND ip_address IS NULL
    ) AS high_risk_missing_ip
FROM transactions;


SELECT
    transaction_id,
    transaction_timestamp,
    account_id,
    amount,
    merchant_category,
    location_country,
    device_id,
    ip_address,
    is_high_risk_ip,
    is_fraud
FROM transactions
WHERE is_high_risk_ip = TRUE
  AND ip_address IS NULL
ORDER BY transaction_timestamp;


SELECT
    is_fraud,
    COUNT(*) AS transaction_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM transactions
WHERE is_high_risk_ip = TRUE
  AND ip_address IS NULL
GROUP BY is_fraud
ORDER BY is_fraud;