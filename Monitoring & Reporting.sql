----Create the Main Fraud Monitoring View----
CREATE OR REPLACE VIEW fraud_monitoring_summary AS
SELECT
COUNT(*) AS total_transactions,
COUNT(*) FILTER (WHERE is_fraud=1) AS confirmed_fraud_transactions,
ROUND((COUNT(*) FILTER (WHERE is_fraud=1)*100.0/COUNT(*))::NUMERIC,2) AS fraud_rate_pct,
ROUND(SUM(amount)::NUMERIC,2) AS total_transaction_amount,
ROUND(SUM(amount) FILTER (WHERE is_fraud=1)::NUMERIC,2) AS total_fraud_amount,
ROUND((SUM(amount) FILTER (WHERE is_fraud=1)*100.0/NULLIF(SUM(amount),0))::NUMERIC,2) AS fraud_amount_share_pct,
COUNT(DISTINCT account_id) AS unique_accounts,
COUNT(DISTINCT account_id) FILTER (WHERE is_fraud=1) AS accounts_with_fraud
FROM transactions;

SELECT * FROM fraud_monitoring_summary;

---High-Risk Transaction Monitoring-----

CREATE OR REPLACE VIEW high_risk_transaction_monitoring AS
WITH transaction_sequence AS (
SELECT transaction_id,account_id,transaction_timestamp,amount,currency,merchant_category,location_country,is_high_risk_ip,is_fraud,LAG(transaction_timestamp) OVER (PARTITION BY account_id ORDER BY transaction_timestamp) AS previous_transaction_timestamp
FROM transactions
),
scored AS (
SELECT *,CASE WHEN amount>=1500 THEN 30 ELSE 0 END+CASE WHEN is_high_risk_ip=TRUE THEN 20 ELSE 0 END+CASE WHEN previous_transaction_timestamp IS NOT NULL AND transaction_timestamp-previous_transaction_timestamp<=INTERVAL '30 minutes' AND amount>=1500 THEN 10 ELSE 0 END+CASE WHEN merchant_category IN ('Luxury Goods','Crypto Exchange') THEN 25 ELSE 0 END AS risk_score
FROM transaction_sequence
)
SELECT transaction_id,account_id,transaction_timestamp,amount,currency,merchant_category,location_country,is_high_risk_ip,risk_score,CASE WHEN risk_score>=70 THEN 'HIGH' WHEN risk_score>=40 THEN 'MEDIUM' ELSE 'LOW' END AS risk_level,is_fraud
FROM scored
WHERE risk_score>=40;

SELECT * FROM high_risk_transaction_monitoring ORDER BY risk_score DESC,transaction_timestamp DESC;


---Fraud Alert Summary Review----

CREATE OR REPLACE VIEW fraud_alert_summary AS
SELECT risk_level,alert_status,
      COUNT(*) AS alert_count,ROUND(AVG(risk_score)::NUMERIC,2) AS avg_risk_score,
	  MIN(created_at) AS first_alert_time,
	  MAX(created_at) AS latest_alert_time
FROM fraud_alerts
GROUP BY risk_level,alert_status;

SELECT * FROM fraud_alert_summary ORDER BY CASE WHEN risk_level='HIGH' THEN 1 WHEN risk_level='MEDIUM' THEN 2 ELSE 3 END,alert_status;