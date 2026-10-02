---Verifying Both Test Scenarios---------

SELECT t.transaction_id,t.amount,t.merchant_category,t.is_high_risk_ip,fa.risk_score,fa.risk_level,fa.triggered_rules,fa.alert_status
FROM transactions t
LEFT JOIN fraud_alerts fa ON t.transaction_id=fa.transaction_id
WHERE t.transaction_id IN ('f9b3e1c2-7a64-4d91-9f25-6c8b3a517e42','a27d91e4-5b83-46c2-91f7-3d6e8a420c15')
ORDER BY t.amount DESC;
------------
SELECT t.transaction_id,t.amount,t.merchant_category,t.is_high_risk_ip,fa.risk_score,fa.risk_level,fa.triggered_rules,fa.alert_status
FROM transactions t
LEFT JOIN fraud_alerts fa ON t.transaction_id=fa.transaction_id
WHERE t.transaction_id IN ('f9b3e1c2-7a64-4d91-9f25-6c8b3a517e42','a27d91e4-5b83-46c2-91f7-3d6e8a420c15')
ORDER BY t.amount DESC;
--------------
WITH test_account AS (
SELECT account_id,MAX(transaction_timestamp) AS last_transaction_time
FROM transactions
GROUP BY account_id
ORDER BY MAX(transaction_timestamp) DESC
LIMIT 1
)
INSERT INTO transactions(transaction_id,transaction_timestamp,account_id,amount,currency,merchant_category,location_country,device_id,ip_address,is_high_risk_ip,is_fraud)
SELECT 'b48c72d1-6e95-4a83-9f21-5c7d304e8162',last_transaction_time+INTERVAL '2 hours',account_id,2000.00,'USD','Grocery','US','TEST_DEVICE_003','198.51.100.20'::INET,FALSE,NULL
FROM test_account;
---------------------------------
SELECT t.transaction_id,t.amount,t.is_high_risk_ip,fa.risk_score,fa.risk_level,fa.triggered_rules,fa.alert_status
FROM transactions t
LEFT JOIN fraud_alerts fa ON t.transaction_id=fa.transaction_id
WHERE t.transaction_id='b48c72d1-6e95-4a83-9f21-5c7d304e8162';

----------------------------------


WITH test_account AS (
SELECT account_id,MAX(transaction_timestamp) AS last_transaction_time
FROM transactions
GROUP BY account_id
ORDER BY MAX(transaction_timestamp) DESC
LIMIT 1
)
INSERT INTO transactions(transaction_id,transaction_timestamp,account_id,amount,currency,merchant_category,location_country,device_id,ip_address,is_high_risk_ip,is_fraud)
SELECT 'c59d83e2-7f16-4b94-a528-6e304915d721',last_transaction_time+INTERVAL '10 minutes',account_id,2000.00,'USD','Grocery','US','TEST_DEVICE_004','198.51.100.30'::INET,FALSE,NULL
FROM test_account;

---Medium Alert ---

SELECT t.transaction_id,t.amount,t.merchant_category,t.is_high_risk_ip,fa.risk_score,fa.risk_level,fa.triggered_rules,fa.alert_status
FROM transactions t
LEFT JOIN fraud_alerts fa ON t.transaction_id=fa.transaction_id
WHERE t.transaction_id='c59d83e2-7f16-4b94-a528-6e304915d721';