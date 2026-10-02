
----Alert Summary-------

SELECT alert_status,risk_level,COUNT(*) AS alert_count,
                    SUM(risk_score) AS total_risk_score,
					ROUND(AVG(risk_score)::NUMERIC,2) AS avg_risk_score
FROM fraud_alerts
GROUP BY alert_status,risk_level
ORDER BY CASE WHEN risk_level='HIGH' THEN 1 WHEN risk_level='MEDIUM' THEN 2 ELSE 3 END,alert_status;


----Create Fraud Alert Monitoring View-----

CREATE OR REPLACE VIEW fraud_alert_monitoring AS
SELECT fa.alert_id,fa.transaction_id,fa.account_id,t.transaction_timestamp,t.amount,t.currency,t.merchant_category,t.location_country,t.is_high_risk_ip,fa.risk_score,fa.risk_level,fa.triggered_rules,fa.alert_status,fa.created_at
FROM fraud_alerts fa
JOIN transactions t ON fa.transaction_id=t.transaction_id
WHERE fa.alert_status IN ('OPEN','INVESTIGATING');

SELECT * FROM fraud_alert_monitoring ORDER BY risk_score DESC,created_at DESC;

SELECT alert_id,transaction_id,account_id,risk_score,risk_level,triggered_rules,alert_status,created_at
FROM fraud_alerts
ORDER BY created_at DESC;

SELECT COUNT(*) AS total_alerts,COUNT(*) FILTER (WHERE alert_status='OPEN') AS open_alerts,COUNT(*) FILTER (WHERE alert_status='INVESTIGATING') AS investigating_alerts,COUNT(*) FILTER (WHERE alert_status='RESOLVED') AS resolved_alerts,COUNT(*) FILTER (WHERE alert_status='FALSE_POSITIVE') AS false_positive_alerts
FROM fraud_alerts;
