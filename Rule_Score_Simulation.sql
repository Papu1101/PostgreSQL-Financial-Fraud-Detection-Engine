-----Historical Risk Score Simulation------

WITH transaction_sequence AS (
SELECT transaction_id,account_id,transaction_timestamp,amount,merchant_category,is_high_risk_ip,is_fraud,LAG(transaction_timestamp) OVER (PARTITION BY account_id ORDER BY transaction_timestamp) AS previous_transaction_timestamp
FROM transactions
),
account_behavior AS (
SELECT account_id,(COUNT(*) FILTER (WHERE is_fraud = 1)*100.0/NULLIF(COUNT(*),0))::NUMERIC AS fraud_rate_pct
FROM transactions
GROUP BY account_id
),
features AS (
SELECT ts.*,ab.fraud_rate_pct,
CASE WHEN ts.amount >= 1500 THEN 30 ELSE 0 END AS rule_01_score,
CASE WHEN ts.is_high_risk_ip = TRUE THEN 20 ELSE 0 END AS rule_02_score,
CASE WHEN ab.fraud_rate_pct >= 12.12 THEN 15 ELSE 0 END AS rule_03_score,
CASE WHEN ts.previous_transaction_timestamp IS NOT NULL AND ts.transaction_timestamp-ts.previous_transaction_timestamp <= INTERVAL '30 minutes' AND ts.amount >= 1500 THEN 10 ELSE 0 END AS rule_04_score,
CASE WHEN ts.merchant_category IN ('Luxury Goods','Crypto Exchange') THEN 25 ELSE 0 END AS rule_05_score
FROM transaction_sequence ts
LEFT JOIN account_behavior ab ON ts.account_id=ab.account_id
),
risk_scores AS (
SELECT *,rule_01_score+rule_02_score+rule_03_score+rule_04_score+rule_05_score AS total_risk_score
FROM features
),
classified AS (
SELECT *,CASE WHEN total_risk_score >= 70 THEN 'HIGH' WHEN total_risk_score >= 40 THEN 'MEDIUM' ELSE 'LOW' END AS risk_level
FROM risk_scores
)
SELECT risk_level,COUNT(*) AS transaction_count,COUNT(*) FILTER (WHERE is_fraud=1) AS fraud_transactions,ROUND((COUNT(*) FILTER (WHERE is_fraud=1)*100.0/COUNT(*))::NUMERIC,2) AS fraud_rate_pct,ROUND(AVG(total_risk_score)::NUMERIC,2) AS avg_risk_score
FROM classified
GROUP BY risk_level
ORDER BY CASE WHEN risk_level='HIGH' THEN 1 WHEN risk_level='MEDIUM' THEN 2 ELSE 3 END;

--Risk Score Performance Validation---

WITH transaction_sequence AS (
SELECT transaction_id,account_id,transaction_timestamp,amount,merchant_category,is_high_risk_ip,is_fraud,LAG(transaction_timestamp) OVER (PARTITION BY account_id ORDER BY transaction_timestamp) AS previous_transaction_timestamp
FROM transactions
),
account_behavior AS (
SELECT account_id,(COUNT(*) FILTER (WHERE is_fraud=1)*100.0/NULLIF(COUNT(*),0))::NUMERIC AS fraud_rate_pct
FROM transactions
GROUP BY account_id
),
scored_transactions AS (
SELECT ts.transaction_id,ts.is_fraud,
CASE WHEN ts.amount>=1500 THEN 30 ELSE 0 END AS rule_01_score,
CASE WHEN ts.is_high_risk_ip=TRUE THEN 20 ELSE 0 END AS rule_02_score,
CASE WHEN ab.fraud_rate_pct>=12.12 THEN 15 ELSE 0 END AS rule_03_score,
CASE WHEN ts.previous_transaction_timestamp IS NOT NULL AND ts.transaction_timestamp-ts.previous_transaction_timestamp<=INTERVAL '30 minutes' AND ts.amount>=1500 THEN 10 ELSE 0 END AS rule_04_score,
CASE WHEN ts.merchant_category IN ('Luxury Goods','Crypto Exchange') THEN 25 ELSE 0 END AS rule_05_score
FROM transaction_sequence ts
LEFT JOIN account_behavior ab ON ts.account_id=ab.account_id
),
risk_scores AS (
SELECT *,rule_01_score+rule_02_score+rule_03_score+rule_04_score+rule_05_score AS total_risk_score
FROM scored_transactions
),
classified AS (
SELECT *,CASE WHEN total_risk_score>=70 THEN 'HIGH' WHEN total_risk_score>=40 THEN 'MEDIUM' ELSE 'LOW' END AS risk_level
FROM risk_scores
)
SELECT risk_level,COUNT(*) AS transactions,COUNT(*) FILTER (WHERE is_fraud=1) AS fraud_transactions,COUNT(*) FILTER (WHERE is_fraud=0) AS non_fraud_transactions,ROUND((COUNT(*) FILTER (WHERE is_fraud=1)*100.0/COUNT(*))::NUMERIC,2) AS fraud_rate_pct,ROUND((COUNT(*) FILTER (WHERE is_fraud=0)*100.0/COUNT(*))::NUMERIC,2) AS false_positive_rate_pct
FROM classified
GROUP BY risk_level
ORDER BY CASE WHEN risk_level='HIGH' THEN 1 WHEN risk_level='MEDIUM' THEN 2 ELSE 3 END;