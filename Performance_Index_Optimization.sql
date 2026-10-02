CREATE INDEX IF NOT EXISTS idx_transactions_account_timestamp
ON transactions(account_id,transaction_timestamp);


EXPLAIN ANALYZE SELECT MAX(transaction_timestamp) FROM transactions 
      WHERE account_id='ACC_PF8NBP8Y' AND transaction_timestamp<'2026-06-19 23:59:00';


CREATE INDEX IF NOT EXISTS idx_transactions_high_risk_ip
ON transactions(is_high_risk_ip);

EXPLAIN ANALYZE SELECT COUNT(*) FROM transactions WHERE is_high_risk_ip=TRUE;

CREATE INDEX IF NOT EXISTS idx_transactions_merchant_category
ON transactions(merchant_category);

EXPLAIN ANALYZE SELECT COUNT(*) FROM transactions WHERE merchant_category IN ('Luxury Goods','Crypto Exchange');