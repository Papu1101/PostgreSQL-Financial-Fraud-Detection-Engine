----Implementing and validating the rule -------
WITH rule_01 AS (
    SELECT
        transaction_id,
        account_id,
        amount,
        is_fraud,
        CASE
            WHEN amount >= 1500 THEN 1
            ELSE 0
        END AS rule_01_high_value
    FROM transactions
)
SELECT
    rule_01_high_value,
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
    ) AS fraud_rate_pct,
    ROUND(
        AVG(amount)::NUMERIC,
        2
    ) AS avg_transaction_amount
FROM rule_01
GROUP BY rule_01_high_value
ORDER BY rule_01_high_value DESC;


---High-Risk IP---

WITH rule_02 AS (
    SELECT
        transaction_id,
        account_id,
        is_high_risk_ip,
        amount,
        is_fraud,
        CASE
            WHEN is_high_risk_ip = TRUE THEN 1
            ELSE 0
        END AS rule_02_high_risk_ip
    FROM transactions
)
SELECT
    rule_02_high_risk_ip,
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
    ) AS fraud_rate_pct,
    ROUND(
        AVG(amount)::NUMERIC,
        2
    ) AS avg_transaction_amount
FROM rule_02
GROUP BY rule_02_high_risk_ip
ORDER BY rule_02_high_risk_ip DESC;

---Combining Rules----

WITH rule_flags AS (
    SELECT
        transaction_id,
        is_fraud,
        CASE
            WHEN amount >= 1500 THEN 1
            ELSE 0
        END AS rule_01_high_value,
        CASE
            WHEN is_high_risk_ip = TRUE THEN 1
            ELSE 0
        END AS rule_02_high_risk_ip
    FROM transactions
)
SELECT
    rule_01_high_value,
    rule_02_high_risk_ip,
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
FROM rule_flags
GROUP BY
    rule_01_high_value,
    rule_02_high_risk_ip
ORDER BY
    rule_01_high_value DESC,
    rule_02_high_risk_ip DESC;

---Customer Behavioral Anomaly----

WITH account_behavior AS (
    SELECT
        account_id,
        COUNT(*) AS total_transactions,
        COUNT(*) FILTER (
            WHERE is_fraud = 1
        ) AS fraud_transactions,
        (
            COUNT(*) FILTER (WHERE is_fraud = 1)
            * 100.0
            / COUNT(*)
        )::NUMERIC AS fraud_rate_pct
    FROM transactions
    GROUP BY account_id
),
distribution AS (
    SELECT
        PERCENTILE_CONT(0.50)
            WITHIN GROUP (
                ORDER BY fraud_rate_pct
            )::NUMERIC AS median_fraud_rate,
        PERCENTILE_CONT(0.75)
            WITHIN GROUP (
                ORDER BY fraud_rate_pct
            )::NUMERIC AS p75_fraud_rate,
        PERCENTILE_CONT(0.90)
            WITHIN GROUP (
                ORDER BY fraud_rate_pct
            )::NUMERIC AS p90_fraud_rate,
        PERCENTILE_CONT(0.95)
            WITHIN GROUP (
                ORDER BY fraud_rate_pct
            )::NUMERIC AS p95_fraud_rate,
        MAX(fraud_rate_pct)::NUMERIC AS max_fraud_rate
    FROM account_behavior
)
SELECT
    ROUND(median_fraud_rate, 2) AS median_fraud_rate,
    ROUND(p75_fraud_rate, 2) AS p75_fraud_rate,
    ROUND(p90_fraud_rate, 2) AS p90_fraud_rate,
    ROUND(p95_fraud_rate, 2) AS p95_fraud_rate,
    ROUND(max_fraud_rate, 2) AS max_fraud_rate
FROM distribution;

---Validating----

WITH account_behavior AS (
    SELECT
        account_id,
        COUNT(*) AS total_transactions,
        COUNT(*) FILTER (
            WHERE is_fraud = 1
        ) AS fraud_transactions,
        (
            COUNT(*) FILTER (WHERE is_fraud = 1)
            * 100.0
            / COUNT(*)
        )::NUMERIC AS fraud_rate_pct
    FROM transactions
    GROUP BY account_id
),
rule_threshold AS (
    SELECT
        PERCENTILE_CONT(0.95)
            WITHIN GROUP (
                ORDER BY fraud_rate_pct
            )::NUMERIC AS p95_fraud_rate
    FROM account_behavior
),
rule_03 AS (
    SELECT
        ab.account_id,
        ab.total_transactions,
        ab.fraud_transactions,
        ab.fraud_rate_pct,
        CASE
            WHEN ab.fraud_rate_pct >= rt.p95_fraud_rate
                THEN 1
            ELSE 0
        END AS rule_03_behavioral_anomaly
    FROM account_behavior ab
    CROSS JOIN rule_threshold rt
)
SELECT
    rule_03_behavioral_anomaly,
    COUNT(*) AS account_count,
    SUM(total_transactions) AS transaction_count,
    SUM(fraud_transactions) AS fraud_transactions,
    ROUND(
        (
            SUM(fraud_transactions)::NUMERIC
            * 100
            / NULLIF(SUM(total_transactions), 0)
        ),
        2
    ) AS transaction_fraud_rate_pct
FROM rule_03
GROUP BY rule_03_behavioral_anomaly
ORDER BY rule_03_behavioral_anomaly DESC;

---Transaction Velocity---

WITH transaction_sequence AS (
    SELECT
        transaction_id,
        account_id,
        transaction_timestamp,
        amount,
        is_high_risk_ip,
        is_fraud,
        LAG(transaction_timestamp) OVER (
            PARTITION BY account_id
            ORDER BY transaction_timestamp
        ) AS previous_transaction_timestamp
    FROM transactions
),
features AS (
    SELECT
        transaction_id,
        account_id,
        amount,
        is_high_risk_ip,
        is_fraud,
        CASE
            WHEN previous_transaction_timestamp IS NULL
                THEN 0
            WHEN transaction_timestamp
                 - previous_transaction_timestamp
                 <= INTERVAL '30 minutes'
                THEN 1
            ELSE 0
        END AS rapid_transaction,
        CASE
            WHEN amount >= 1500 THEN 1
            ELSE 0
        END AS high_value,
        CASE
            WHEN is_high_risk_ip = TRUE THEN 1
            ELSE 0
        END AS high_risk_ip
    FROM transaction_sequence
)
SELECT
    rapid_transaction,
    high_value,
    high_risk_ip,
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
FROM features
GROUP BY
    rapid_transaction,
    high_value,
    high_risk_ip
ORDER BY
    rapid_transaction DESC,
    high_value DESC,
    high_risk_ip DESC;


--Merchant Category Risk---

WITH category_metrics AS (
    SELECT
        merchant_category,
        COUNT(*) AS total_transactions,
        COUNT(*) FILTER (
            WHERE is_fraud = 1
        ) AS fraud_transactions,
        SUM(amount)::NUMERIC AS total_amount,
        COALESCE(
            SUM(amount) FILTER(
                WHERE is_fraud = 1),0)::NUMERIC AS fraud_amount
    FROM transactions
    GROUP BY merchant_category
),
category_rates AS (
    SELECT
        merchant_category,
        total_transactions,
        fraud_transactions,
        total_amount,
        fraud_amount,
        (
            fraud_transactions::NUMERIC
            * 100
            / NULLIF(total_transactions, 0)
        ) AS fraud_rate_pct
    FROM category_metrics
),
category_distribution AS (
    SELECT
        *,
        PERCENT_RANK() OVER (
            ORDER BY fraud_rate_pct
        ) AS fraud_rate_percentile,
        RANK() OVER (
            ORDER BY fraud_rate_pct DESC
        ) AS fraud_rate_rank
    FROM category_rates
)
SELECT
    merchant_category,
    total_transactions,
    fraud_transactions,
    ROUND(fraud_rate_pct, 2) AS fraud_rate_pct,
    ROUND(total_amount, 2) AS total_amount,
    ROUND(fraud_amount, 2) AS fraud_amount,
    ROUND(
        (
            fraud_transactions::NUMERIC
            * 100
            / SUM(fraud_transactions) OVER ()
        ),
        2
    ) AS share_of_all_fraud_pct,
    ROUND(
        (fraud_rate_percentile * 100)::NUMERIC,
        2
    ) AS fraud_rate_percentile,
    fraud_rate_rank
FROM category_distribution
ORDER BY fraud_rate_rank;

---Validating------

WITH rule_05 AS (
    SELECT
        transaction_id,
        merchant_category,
        is_fraud,
        CASE
            WHEN merchant_category IN (
                'Luxury Goods',
                'Crypto Exchange'
            )
            THEN 1
            ELSE 0
        END AS rule_05_category_risk
    FROM transactions
)
SELECT
    rule_05_category_risk,
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
    ) AS fraud_rate_pct,
    ROUND(
        (
            COUNT(*) FILTER (WHERE is_fraud = 1)
            * 100.0
            / SUM(COUNT(*) FILTER (WHERE is_fraud = 1))
              OVER ()
        )::NUMERIC,
        2
    ) AS fraud_coverage_pct
FROM rule_05
GROUP BY rule_05_category_risk
ORDER BY rule_05_category_risk DESC;