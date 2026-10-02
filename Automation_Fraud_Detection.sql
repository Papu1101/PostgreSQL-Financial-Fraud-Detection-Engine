-----Creating the Fraud Alerts Table----------

CREATE TABLE fraud_alerts (
alert_id BIGSERIAL PRIMARY KEY,
transaction_id TEXT NOT NULL REFERENCES transactions(transaction_id),
account_id TEXT NOT NULL,
risk_score INTEGER NOT NULL,
risk_level TEXT NOT NULL,
triggered_rules TEXT NOT NULL,
alert_status TEXT NOT NULL DEFAULT 'OPEN',
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT chk_risk_score CHECK (risk_score BETWEEN 0 AND 100),
CONSTRAINT chk_risk_level CHECK (risk_level IN ('LOW','MEDIUM','HIGH')),
CONSTRAINT chk_alert_status CHECK (alert_status IN ('OPEN','INVESTIGATING','RESOLVED','FALSE_POSITIVE')),
CONSTRAINT uq_fraud_alert_transaction UNIQUE (transaction_id)
);

----Creating the Risk Evaluation Function----

CREATE OR REPLACE FUNCTION evaluate_fraud_risk(p_transaction_id TEXT)
RETURNS TABLE(risk_score INTEGER,risk_level TEXT,triggered_rules TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
v_account_id TEXT;
v_transaction_timestamp TIMESTAMP;
v_amount NUMERIC(15,2);
v_merchant_category TEXT;
v_is_high_risk_ip BOOLEAN;
v_previous_transaction_timestamp TIMESTAMP;
v_score INTEGER:=0;
v_rules TEXT:='';
BEGIN
SELECT account_id,transaction_timestamp,amount,merchant_category,is_high_risk_ip
INTO v_account_id,v_transaction_timestamp,v_amount,v_merchant_category,v_is_high_risk_ip
FROM transactions
WHERE transaction_id=p_transaction_id;
IF NOT FOUND THEN
RAISE EXCEPTION 'Transaction % does not exist',p_transaction_id;
END IF;
SELECT MAX(transaction_timestamp)
INTO v_previous_transaction_timestamp
FROM transactions
WHERE account_id=v_account_id
AND transaction_timestamp<v_transaction_timestamp;
IF v_amount>=1500 THEN
v_score:=v_score+30;
v_rules:=v_rules||'HIGH_VALUE,';
END IF;
IF v_is_high_risk_ip=TRUE THEN
v_score:=v_score+20;
v_rules:=v_rules||'HIGH_RISK_IP,';
END IF;
IF v_previous_transaction_timestamp IS NOT NULL
AND v_transaction_timestamp-v_previous_transaction_timestamp<=INTERVAL '30 minutes'
AND v_amount>=1500 THEN
v_score:=v_score+10;
v_rules:=v_rules||'RAPID_HIGH_VALUE,';
END IF;
IF v_merchant_category IN ('Luxury Goods','Crypto Exchange') THEN
v_score:=v_score+25;
v_rules:=v_rules||'HIGH_RISK_MERCHANT,';
END IF;
IF v_score>=70 THEN
risk_level:='HIGH';
ELSIF v_score>=40 THEN
risk_level:='MEDIUM';
ELSE
risk_level:='LOW';
END IF;
v_rules:=RTRIM(v_rules,',');
RETURN QUERY
SELECT v_score,risk_level,v_rules;
END;

----Testing the Fraud Evaluation Function----

SELECT transaction_id FROM transactions LIMIT 5;

SELECT * FROM evaluate_fraud_risk('7368eca9-7875-42ea-8f50-8c1742915a0c'::TEXT);


CREATE OR REPLACE FUNCTION evaluate_fraud_risk(p_transaction_id TEXT)
RETURNS TABLE(risk_score INTEGER,risk_level TEXT,triggered_rules TEXT)
AS $$
BEGIN
RETURN QUERY
SELECT 0,'LOW'::TEXT,'TEST'::TEXT;
END;

---Creating The trigger ---

CREATE OR REPLACE FUNCTION fraud_detection_trigger()


SELECT alert_id,transaction_id,account_id,risk_score,risk_level,triggered_rules,alert_status,created_at
FROM fraud_alerts
WHERE transaction_id='f9b3e1c2-7a64-4d91-9f25-6c8b3a517e42';


WITH test_account AS (
SELECT account_id,MAX(transaction_timestamp) AS last_transaction_time
FROM transactions
WHERE transaction_id='f9b3e1c2-7a64-4d91-9f25-6c8b3a517e42'
GROUP BY account_id
)
INSERT INTO transactions(transaction_id,transaction_timestamp,account_id,amount,currency,merchant_category,location_country,device_id,ip_address,is_high_risk_ip,is_fraud)
SELECT 'a27d91e4-5b83-46c2-91f7-3d6e8a420c15',last_transaction_time+INTERVAL '1 hour',account_id,75.00,'USD','Grocery','US','TEST_DEVICE_002','198.51.100.10'::INET,FALSE,NULL
FROM test_account;
RETURNS TRIGGER
AS $$
DECLARE
v_risk RECORD;
BEGIN
SELECT * INTO v_risk
FROM evaluate_fraud_risk(NEW.transaction_id);
IF v_risk.risk_level IN ('MEDIUM','HIGH') THEN
INSERT INTO fraud_alerts(transaction_id,account_id,risk_score,risk_level,triggered_rules)
VALUES(NEW.transaction_id,NEW.account_id,v_risk.risk_score,v_risk.risk_level,v_risk.triggered_rules);
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_fraud_detection
AFTER INSERT ON transactions
FOR EACH ROW
EXECUTE FUNCTION fraud_detection_trigger();


WITH test_account AS (
SELECT account_id,MAX(transaction_timestamp) AS last_transaction_time
FROM transactions
GROUP BY account_id
ORDER BY MAX(transaction_timestamp) DESC
LIMIT 1
)
INSERT INTO transactions(transaction_id,transaction_timestamp,account_id,amount,currency,merchant_category,location_country,device_id,ip_address,is_high_risk_ip,is_fraud)
SELECT 'f9b3e1c2-7a64-4d91-9f25-6c8b3a517e42',last_transaction_time+INTERVAL '10 minutes',account_id,6000.00,'USD','Luxury Goods','US','TEST_DEVICE_001','192.0.2.10'::INET,TRUE,NULL
FROM test_account;

SELECT COUNT(*) AS alert_count
FROM fraud_alerts
WHERE transaction_id='a27d91e4-5b83-46c2-91f7-3d6e8a420c15';