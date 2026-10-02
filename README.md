# PostgreSQL-Financial-Fraud-Detection-Engine
Built an end-to-end financial fraud detection system using PostgreSQL and PL/pgSQL. Analyzed 20K transactions, engineered fraud rules, developed risk scoring, automated detection with triggers, generated fraud alerts, and optimized queries using indexes and EXPLAIN ANALYZE.

An end-to-end **financial transaction fraud detection system built entirely with PostgreSQL and PL/pgSQL**. The project analyzes historical transaction behavior, engineers fraud detection rules, calculates risk scores, automatically evaluates new transactions using database triggers, generates fraud alerts, and optimizes analytical queries.

## Project Overview

Financial transaction systems need to identify suspicious activity quickly and consistently. This project demonstrates how a fraud detection pipeline can be designed entirely inside PostgreSQL, from raw transaction ingestion through historical analysis and automated fraud alert generation.

The system uses a **rule-based risk scoring engine** supported by historical fraud analysis and PostgreSQL automation.

### Dataset

* **20,000 transactions**
* **500 accounts**
* **9 merchant categories**
* **5 countries**
* **3 currencies**
* **1,003 confirmed fraud transactions**
* **5.02% overall fraud rate**
* **$7.48M total transaction value**
* **$4.36M fraud transaction value**
* **58.31% of transaction value associated with confirmed fraud**

## Business Problem

Historical fraud analysis can identify suspicious patterns, but a production system also needs to evaluate **new transactions automatically**.

The objective of this project was to build a PostgreSQL-based system that:

1. Validates incoming transaction data
2. Analyzes historical fraud behavior
3. Identifies high-risk transaction patterns
4. Converts those patterns into fraud detection rules
5. Calculates a risk score
6. Classifies transactions into risk levels
7. Automatically evaluates newly inserted transactions
8. Creates fraud alerts for suspicious transactions
9. Provides monitoring and reporting views
10. Optimizes frequently used fraud queries

## Solution Architecture

```text
Raw CSV Data
     │
     ▼
staging_transactions
     │
     ▼
Data Cleaning & Validation
     │
     ▼
transactions
     │
     ▼
Historical Fraud Analysis
     │
     ▼
Fraud Rule Engineering
     │
     ▼
Risk Scoring Engine
     │
     ▼
PL/pgSQL Function
     │
     ▼
PostgreSQL Trigger
     │
     ├───────────────┐
     ▼               ▼
LOW             MEDIUM / HIGH
                     │
                     ▼
               fraud_alerts
                     │
                     ▼
             Monitoring Views
```

## Database Tables

### `staging_transactions`

Temporary/raw layer used for loading and validating CSV transaction data before production insertion.

### `transactions`

Validated production transaction table.

| Column                | Data Type     |
| --------------------- | ------------- |
| transaction_id        | TEXT          |
| transaction_timestamp | TIMESTAMP     |
| account_id            | TEXT          |
| amount                | NUMERIC(15,2) |
| currency              | TEXT          |
| merchant_category     | TEXT          |
| location_country      | TEXT          |
| device_id             | TEXT          |
| ip_address            | INET          |
| time_since_last_txn   | NUMERIC(12,2) |
| is_high_risk_ip       | BOOLEAN       |
| is_fraud              | INTEGER       |

### `fraud_alerts`

Stores automatically generated fraud alerts.

| Column          | Purpose                         |
| --------------- | ------------------------------- |
| alert_id        | Alert identifier                |
| transaction_id  | Associated transaction          |
| account_id      | Customer/account                |
| risk_score      | Calculated risk score           |
| risk_level      | LOW / MEDIUM / HIGH             |
| triggered_rules | Rules responsible for the score |
| alert_status    | Alert workflow status           |
| created_at      | Alert creation timestamp        |

## Data Cleaning & Validation

The project included PostgreSQL-based data quality checks for:

* Missing values
* Duplicate transaction IDs
* Exact duplicate records
* Invalid transaction amounts
* Invalid fraud flags
* Negative transaction intervals
* Timestamp validation
* Logical inconsistencies between IP fields and risk indicators

Key findings included:

* **No duplicate transaction IDs**
* **No exact duplicate records**
* **No invalid transaction amounts**
* **No invalid fraud flags**
* **No negative transaction velocity values**
* Missing `device_id` and `ip_address` values were retained where appropriate
* Transactions where `is_high_risk_ip = TRUE` but `ip_address` was NULL were identified as logical data-quality inconsistencies

## Historical Fraud Analysis

Advanced PostgreSQL SQL was used to analyze historical fraud behavior.

### Transaction Analysis

Transaction value was highly concentrated in:

* Luxury Goods
* Crypto Exchange

These two categories represented approximately **50.83% of total transaction value**.

### Fraud vs Non-Fraud

Confirmed fraud represented only **5.02% of transactions**, but approximately **58.31% of transaction value**.

Average transaction amount:

```text
Fraud     → $4,349.25
Non-Fraud → $164.17
```

This represented a substantial difference in transaction value between fraud and non-fraud activity.

### Customer Behavior

Historical account analysis showed:

* 500 unique accounts
* 427 accounts had at least one confirmed fraud transaction
* Median account fraud rate was approximately 4.7%
* Some accounts exhibited substantially higher historical fraud rates

Customer behavior was used as a supporting analytical signal during historical analysis.

### Transaction Velocity

`LAG()` was used to reconstruct the previous transaction for each account.

Velocity alone was not sufficiently discriminative, so a simple rule such as:

```sql
previous_transaction <= 30 minutes
```

was not used independently.

Instead, rapid transaction behavior was treated as an **interaction signal with high transaction value**.

### Amount Analysis

Transaction amount was one of the strongest fraud indicators.

Historical analysis found no observed fraud below $1,500, while transaction amounts at or above $1,500 contained the overwhelming majority of observed fraud.

This led to the primary high-value transaction rule.

### Geographic Analysis

Country-level fraud rates were relatively similar across the observed countries.

A country-change analysis using `LAG()` also showed that geographic change alone did not provide a sufficiently strong standalone fraud signal.

Therefore, geographic movement was not used as an independent production rule.

## Fraud Detection Rules

The final production scoring engine uses observable transaction attributes.

### Rule 1 — High-Value Transaction

```sql
amount >= 1500
```

**Score: 30**

Historical validation:

* 1,071 transactions triggered the rule
* 1,003 were confirmed fraud
* Fraud rate: **93.65%**
* Fraud coverage: **100%**

### Rule 2 — High-Risk IP

```sql
is_high_risk_ip = TRUE
```

**Score: 20**

Historical validation:

* 1,469 transactions triggered the rule
* 526 were confirmed fraud
* Fraud rate: **35.81%**
* Fraud coverage: **52.44%**

The signal becomes substantially stronger when combined with high transaction value.

### Rule 3 — Rapid + High-Value Transaction

```text
Previous transaction within 30 minutes
AND
Amount >= $1,500
```

**Score: 10**

Velocity was intentionally used as an **interaction rule**, rather than as a standalone fraud rule.

### Rule 4 — High-Risk Merchant Category

```sql
merchant_category IN ('Luxury Goods','Crypto Exchange')
```

**Score: 25**

Historical validation:

* 1,449 transactions triggered the rule
* 853 were confirmed fraud
* Fraud rate: **58.87%**
* Fraud coverage: **85.04%**

## Risk Scoring Engine

The production scoring engine calculates:

```text
High Value Transaction       → +30
High-Risk IP                 → +20
Rapid + High Value           → +10
High-Risk Merchant Category  → +25
```

Maximum theoretical score:

```text
85
```

### Risk Classification

```text
0–39   → LOW
40–69  → MEDIUM
70–100 → HIGH
```

The scoring system is a **rule-based risk score, not a probability of fraud**.

## PostgreSQL Automation

### PL/pgSQL Risk Function

The project includes:

```sql
evaluate_fraud_risk(p_transaction_id TEXT)
```

The function:

1. Retrieves transaction information
2. Identifies the account's previous transaction
3. Evaluates fraud rules
4. Calculates the total risk score
5. Assigns a risk level
6. Records the triggered rules

### PostgreSQL Trigger

A PostgreSQL `AFTER INSERT` trigger automatically evaluates every newly inserted transaction.

```text
New Transaction
      ↓
fraud_detection_trigger()
      ↓
evaluate_fraud_risk()
      ↓
Risk Score
      ↓
Risk Level
      ↓
MEDIUM / HIGH
      ↓
fraud_alerts
```

Low-risk transactions do not generate fraud alerts.

## Fraud Alert System

The `fraud_alerts` table supports:

* Alert ID
* Transaction ID
* Account ID
* Risk score
* Risk level
* Triggered rules
* Alert status
* Alert creation time

Supported alert statuses:

```text
OPEN
INVESTIGATING
RESOLVED
FALSE_POSITIVE
```

A unique constraint prevents duplicate alerts for the same transaction.

## Monitoring & Reporting

The project includes SQL views for operational monitoring.

### `fraud_monitoring_summary`

Provides:

* Total transactions
* Confirmed fraud transactions
* Fraud rate
* Total transaction amount
* Total fraud amount
* Fraud amount share
* Unique accounts
* Accounts with fraud

### `high_risk_transaction_monitoring`

Provides transactions classified as:

```text
MEDIUM
HIGH
```

along with their:

* Risk score
* Risk level
* Triggered risk indicators
* Transaction details

### `fraud_alert_summary`

Provides alert counts by:

* Risk level
* Alert status
* Average risk score
* First alert time
* Latest alert time

## Performance Optimization

Indexes were created for frequently used fraud detection queries:

```sql
CREATE INDEX idx_transactions_account_timestamp
ON transactions(account_id,transaction_timestamp);

CREATE INDEX idx_transactions_high_risk_ip
ON transactions(is_high_risk_ip);

CREATE INDEX idx_transactions_merchant_category
ON transactions(merchant_category);
```

Performance was validated using:

```sql
EXPLAIN ANALYZE
```

The tested queries produced **Index Only Scan** plans, demonstrating effective index utilization.

## End-to-End Testing

The automated fraud detection pipeline was tested using three transaction scenarios.

### Low Risk

A normal low-value transaction with no additional risk indicators.

**Expected:** LOW risk, no alert.

**Result:** ✅ Passed

### Medium Risk

A high-value transaction combined with rapid transaction velocity.

**Expected:** MEDIUM risk, fraud alert created.

**Result:** ✅ Passed

### High Risk

A high-value transaction combined with:

* High-risk IP
* Rapid transaction velocity
* High-risk merchant category

**Expected:** HIGH risk, fraud alert created.

**Result:** ✅ Passed

## SQL Techniques Used

This project demonstrates advanced PostgreSQL skills including:

* CTEs
* Window Functions
* `LAG()`
* `ROW_NUMBER()`
* `RANK()`
* `PERCENT_RANK()`
* `PERCENTILE_CONT()`
* Conditional Aggregation
* `FILTER`
* `CASE`
* `NULLIF`
* Date/Time Arithmetic
* `INTERVAL`
* Type Casting
* Views
* PL/pgSQL Functions
* Triggers
* Constraints
* Indexing
* `EXPLAIN ANALYZE`

## Production Design Considerations

The historical fraud label `is_fraud` was used for **historical analysis and validation**, not as an input to real-time evaluation of a new transaction.

This prevents target leakage when evaluating unseen transactions.

The behavioral fraud-rate analysis therefore remains a **historical analytical signal** rather than a direct real-time rule in the current production function.

The dataset also contains synthetic test transactions used to validate the trigger and alert workflow. These should be removed before presenting the final cleaned production dataset.

## Project Outcomes

The project demonstrates how PostgreSQL can support a complete fraud analytics and detection workflow without requiring Python, Power BI, or external machine-learning infrastructure.

Key outcomes:

* Identified major historical fraud patterns
* Engineered explainable fraud rules
* Developed a rule-based risk scoring engine
* Automated fraud evaluation using PL/pgSQL
* Implemented PostgreSQL triggers for real-time-style transaction evaluation
* Created a structured fraud alert system
* Built monitoring views for fraud operations
* Optimized analytical queries with indexing and execution-plan analysis

## Technologies

**Database:** PostgreSQL

**Languages:** SQL, PL/pgSQL

**Core Concepts:** Fraud Analytics, Rule Engineering, Risk Scoring, Database Automation, Query Optimization

## Repository Structure

text
Financial-Transaction-Fraud-Detection/
│
├── README.md
├── data/
│   └── transactions.csv
│
├── sql/
│   ├── 01_database_setup.sql
│   ├── 02_data_loading.sql
│   ├── 03_data_validation.sql
│   ├── 04_historical_fraud_analysis.sql
│   ├── 05_fraud_rule_engineering.sql
│   ├── 06_risk_scoring.sql
│   ├── 07_plpgsql_fraud_function.sql
│   ├── 08_fraud_trigger.sql
│   ├── 09_performance_optimization.sql
│   └── 10_monitoring_reporting.sql
│
└── results/
    └── analysis_results/
```

## Author

**Papu Singh Deo**

Data Analyst | SQL | PostgreSQL | Fraud Analytics | Data Analytics
