----Transactional Analysis ------

WITH transaction_metrics AS (
    SELECT
        merchant_category,
        COUNT(*) AS total_transactions,
        SUM(amount) AS total_amount,
        AVG(amount) AS avg_amount,
        COUNT(*) FILTER (WHERE is_fraud = 1) AS fraud_transactions,
        SUM(amount) FILTER (WHERE is_fraud = 1) AS fraud_amount
    FROM transactions
    GROUP BY merchant_category
)
SELECT
    merchant_category,
    total_transactions,
    ROUND(total_amount, 2) AS total_amount,
    ROUND(avg_amount, 2) AS avg_amount,
    fraud_transactions,
    ROUND(
        fraud_transactions * 100.0 / total_transactions,
        2
    ) AS fraud_rate_pct,
    ROUND(fraud_amount, 2) AS fraud_amount,
    ROUND(
        total_amount * 100.0 /
        SUM(total_amount) OVER (),
        2
    ) AS transaction_value_share_pct
FROM transaction_metrics
ORDER BY fraud_rate_pct DESC;


---Fraud vs Non-Fraud Analysis---

WITH fraud_metrics AS (
    SELECT
        CASE
            WHEN is_fraud = 1 THEN 'Fraud'
            ELSE 'Non-Fraud'
        END AS transaction_status,
        COUNT(*) AS transaction_count,
        SUM(amount) AS total_amount,
        AVG(amount) AS avg_amount,
        MIN(amount) AS min_amount,
        MAX(amount) AS max_amount,
        COUNT(DISTINCT account_id) AS unique_accounts
    FROM transactions
    GROUP BY is_fraud
),
overall AS (
    SELECT
        SUM(transaction_count) AS total_transactions,
        SUM(total_amount) AS total_amount
    FROM fraud_metrics
)
SELECT
    fm.transaction_status,
    fm.transaction_count,
    ROUND(
        fm.transaction_count * 100.0 /
        o.total_transactions,
        2
    ) AS transaction_share_pct,
    ROUND(fm.total_amount, 2) AS total_amount,
    ROUND(
        fm.total_amount * 100.0 /
        o.total_amount,
        2
    ) AS amount_share_pct,
    ROUND(fm.avg_amount, 2) AS avg_amount,
    ROUND(fm.min_amount, 2) AS min_amount,
    ROUND(fm.max_amount, 2) AS max_amount,
    fm.unique_accounts
FROM fraud_metrics fm
CROSS JOIN overall o
ORDER BY fm.transaction_status DESC;

---Customer Behavior Analysis----

WITH account_metrics AS (
    SELECT
        account_id,
        COUNT(*) AS total_transactions,
        COUNT(*) FILTER (
            WHERE is_fraud = 1
        ) AS fraud_transactions,
        SUM(amount) AS total_amount,
        SUM(amount) FILTER (
            WHERE is_fraud = 1
        ) AS fraud_amount,
        AVG(amount) AS avg_transaction_amount,
        MAX(amount) AS max_transaction_amount,
        COUNT(DISTINCT merchant_category) AS merchant_categories_used
    FROM transactions
    GROUP BY account_id
),
account_analysis AS (
    SELECT
        *,
        ROUND(
            fraud_transactions * 100.0 /
            NULLIF(total_transactions, 0),
            2
        ) AS fraud_rate_pct,
        ROUND(
            fraud_amount * 100.0 /
            NULLIF(total_amount, 0),
            2
        ) AS fraud_amount_share_pct,
        RANK() OVER (
            ORDER BY fraud_transactions DESC
        ) AS fraud_transaction_rank,
        RANK() OVER (
            ORDER BY fraud_amount DESC
        ) AS fraud_amount_rank
    FROM account_metrics
)
SELECT *
FROM account_analysis
ORDER BY fraud_transactions DESC,
         fraud_amount DESC;


---Transaction Velocity----

WITH transaction_sequence AS (
    SELECT
        transaction_id,
        account_id,
        transaction_timestamp,
        amount,
        is_fraud,
        LAG(transaction_timestamp) OVER (
            PARTITION BY account_id
            ORDER BY transaction_timestamp
        ) AS previous_transaction_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY transaction_timestamp
        ) AS transaction_number
    FROM transactions
)
SELECT
    transaction_id,
    account_id,
    transaction_timestamp,
    previous_transaction_timestamp,
    ROUND(
        EXTRACT(
            EPOCH FROM (
                transaction_timestamp -
                previous_transaction_timestamp
            )
        ) / 60.0,
        2
    ) AS minutes_since_previous_txn,
    transaction_number,
    amount,
    is_fraud
FROM transaction_sequence
WHERE previous_transaction_timestamp IS NOT NULL
ORDER BY account_id, transaction_timestamp
LIMIT 100;

---

WITH transaction_sequence AS (
    SELECT
        transaction_id,
        account_id,
        transaction_timestamp,
        is_fraud,
        LAG(transaction_timestamp) OVER (
            PARTITION BY account_id
            ORDER BY transaction_timestamp
        ) AS previous_transaction_timestamp
    FROM transactions
),
velocity AS (
    SELECT
        transaction_id,
        account_id,
        transaction_timestamp,
        is_fraud,
        (
            EXTRACT(
                EPOCH FROM (
                    transaction_timestamp -
                    previous_transaction_timestamp
                )
            ) / 60
        )::NUMERIC AS minutes_since_previous_txn
    FROM transaction_sequence
    WHERE previous_transaction_timestamp IS NOT NULL
)
SELECT
    CASE
        WHEN is_fraud = 1 THEN 'Fraud'
        ELSE 'Non-Fraud'
    END AS transaction_status,
    COUNT(*) AS transaction_count,
    ROUND(
        AVG(minutes_since_previous_txn),
        2
    ) AS avg_minutes,
    ROUND(
        PERCENTILE_CONT(0.25)
        WITHIN GROUP (
            ORDER BY minutes_since_previous_txn
        )::NUMERIC,
        2
    ) AS p25_minutes,
    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (
            ORDER BY minutes_since_previous_txn
        )::NUMERIC,
        2
    ) AS median_minutes,
    ROUND(
        PERCENTILE_CONT(0.75)
        WITHIN GROUP (
            ORDER BY minutes_since_previous_txn
        )::NUMERIC,
        2
    ) AS p75_minutes,
    ROUND(
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (
            ORDER BY minutes_since_previous_txn
        )::NUMERIC,
        2
    ) AS p90_minutes,
    ROUND(
        PERCENTILE_CONT(0.95)
        WITHIN GROUP (
            ORDER BY minutes_since_previous_txn
        )::NUMERIC,
        2
    ) AS p95_minutes,
    ROUND(
        MIN(minutes_since_previous_txn),
        2
    ) AS minimum_minutes
FROM velocity
GROUP BY is_fraud
ORDER BY is_fraud DESC;

---Amount Pattern Analysis----

WITH amount_distribution AS (
    SELECT
        is_fraud,
        COUNT(*) AS transaction_count,
        AVG(amount)::NUMERIC AS avg_amount,
        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY amount)::NUMERIC AS p25,
        PERCENTILE_CONT(0.50)
            WITHIN GROUP (ORDER BY amount)::NUMERIC AS median,
        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY amount)::NUMERIC AS p75,
        PERCENTILE_CONT(0.90)
            WITHIN GROUP (ORDER BY amount)::NUMERIC AS p90,
        PERCENTILE_CONT(0.95)
            WITHIN GROUP (ORDER BY amount)::NUMERIC AS p95,
        PERCENTILE_CONT(0.99)
            WITHIN GROUP (ORDER BY amount)::NUMERIC AS p99,
        MIN(amount)::NUMERIC AS minimum_amount,
        MAX(amount)::NUMERIC AS maximum_amount
    FROM transactions
    GROUP BY is_fraud
)
SELECT
    CASE
        WHEN is_fraud = 1 THEN 'Fraud'
        ELSE 'Non-Fraud'
    END AS transaction_status,
    transaction_count,
    ROUND(avg_amount, 2) AS avg_amount,
    ROUND(p25, 2) AS p25_amount,
    ROUND(median, 2) AS median_amount,
    ROUND(p75, 2) AS p75_amount,
    ROUND(p90, 2) AS p90_amount,
    ROUND(p95, 2) AS p95_amount,
    ROUND(p99, 2) AS p99_amount,
    ROUND(minimum_amount, 2) AS minimum_amount,
    ROUND(maximum_amount, 2) AS maximum_amount
FROM amount_distribution
ORDER BY is_fraud DESC;

---Fraud Rate by Amount Band---

WITH amount_bands AS (
    SELECT
        CASE
            WHEN amount < 100 THEN '< $100'
            WHEN amount < 500 THEN '$100 - $499'
            WHEN amount < 1000 THEN '$500 - $999'
            WHEN amount < 1500 THEN '$1,000 - $1,499'
            WHEN amount < 2000 THEN '$1,500 - $1,999'
            WHEN amount < 3000 THEN '$2,000 - $2,999'
            WHEN amount < 5000 THEN '$3,000 - $4,999'
            WHEN amount < 7000 THEN '$5,000 - $6,999'
            ELSE '$7,000+'
        END AS amount_band,
        CASE
            WHEN amount < 100 THEN 1
            WHEN amount < 500 THEN 2
            WHEN amount < 1000 THEN 3
            WHEN amount < 1500 THEN 4
            WHEN amount < 2000 THEN 5
            WHEN amount < 3000 THEN 6
            WHEN amount < 5000 THEN 7
            WHEN amount < 7000 THEN 8
            ELSE 9
        END AS band_order,
        amount,
        is_fraud
    FROM transactions
)
SELECT
    amount_band,
    COUNT(*) AS transaction_count,
    COUNT(*) FILTER (
        WHERE is_fraud = 1
    ) AS fraud_transactions,
    ROUND(
        COUNT(*) FILTER (WHERE is_fraud = 1)::NUMERIC
        * 100
        / COUNT(*),
        2
    ) AS fraud_rate_pct,
    ROUND(
        SUM(amount)::NUMERIC,
        2
    ) AS total_transaction_amount,
    ROUND(
        SUM(amount) FILTER (
            WHERE is_fraud = 1
        )::NUMERIC,
        2
    ) AS fraud_amount
FROM amount_bands
GROUP BY
    amount_band,
    band_order
ORDER BY band_order;

---Geographic Patterns---

WITH country_metrics AS (
    SELECT
        location_country,
        COUNT(*) AS total_transactions,
        COUNT(*) FILTER (
            WHERE is_fraud = 1
        ) AS fraud_transactions,
        SUM(amount) AS total_amount,
        SUM(amount) FILTER (
            WHERE is_fraud = 1
        ) AS fraud_amount
    FROM transactions
    GROUP BY location_country
),
country_analysis AS (
    SELECT
        location_country,
        total_transactions,
        fraud_transactions,
        total_amount,
        fraud_amount,
        ROUND(
            fraud_transactions::NUMERIC
            * 100
            / NULLIF(total_transactions, 0),
            2
        ) AS fraud_rate_pct,
        ROUND(
            fraud_amount::NUMERIC
            * 100
            / NULLIF(total_amount, 0),
            2
        ) AS fraud_amount_share_pct
    FROM country_metrics
)
SELECT
    location_country,
    total_transactions,
    fraud_transactions,
    fraud_rate_pct,
    ROUND(total_amount, 2) AS total_amount,
    ROUND(fraud_amount, 2) AS fraud_amount,
    fraud_amount_share_pct,
    RANK() OVER (
        ORDER BY fraud_rate_pct DESC
    ) AS fraud_rate_rank,
    ROUND(
        fraud_transactions::NUMERIC
        * 100
        / SUM(fraud_transactions) OVER (),
        2
    ) AS share_of_all_fraud_pct
FROM country_analysis
ORDER BY fraud_rate_rank;

---Geographic Behavioral Anomaly----

WITH transaction_sequence AS (
    SELECT
        transaction_id,
        account_id,
        transaction_timestamp,
        location_country,
        amount,
        is_fraud,
        LAG(location_country) OVER (
            PARTITION BY account_id
            ORDER BY transaction_timestamp
        ) AS previous_country,
        LAG(transaction_timestamp) OVER (
            PARTITION BY account_id
            ORDER BY transaction_timestamp
        ) AS previous_transaction_timestamp
    FROM transactions
)
SELECT
    transaction_id,
    account_id,
    transaction_timestamp,
    previous_country,
    location_country,
    ROUND(
        (
            EXTRACT(
                EPOCH FROM (
                    transaction_timestamp -
                    previous_transaction_timestamp
                )
            ) / 360
        )::NUMERIC,
        2
    ) AS hours_since_previous_txn,
    amount,
    is_fraud
FROM transaction_sequence
WHERE previous_country IS NOT NULL
  AND previous_country <> location_country
ORDER BY transaction_timestamp;

---Geographic Change vs No Change----

WITH transaction_sequence AS (
    SELECT
        transaction_id,
        account_id,
        transaction_timestamp,
        location_country,
        is_fraud,
        LAG(location_country) OVER (
            PARTITION BY account_id
            ORDER BY transaction_timestamp
        ) AS previous_country
    FROM transactions
),
geographic_behavior AS (
    SELECT
        CASE
            WHEN previous_country IS NULL
                THEN 'First Transaction'
            WHEN previous_country <> location_country
                THEN 'Country Changed'
            ELSE 'Same Country'
        END AS geographic_behavior,
        is_fraud
    FROM transaction_sequence
)
SELECT
    geographic_behavior,
    COUNT(*) AS transaction_count,
    COUNT(*) FILTER (
        WHERE is_fraud = 1
    ) AS fraud_transactions,
    ROUND(
        (
            COUNT(*) FILTER (WHERE is_fraud = 1)
            * 100.0
            / COUNT(*)
        )::NUMERIC,
        2
    ) AS fraud_rate_pct
FROM geographic_behavior
GROUP BY geographic_behavior
ORDER BY
    CASE geographic_behavior
        WHEN 'Country Changed' THEN 1
        WHEN 'Same Country' THEN 2
        ELSE 3
    END;