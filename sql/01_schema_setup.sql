-- ====================================================================
-- Project: Customer Churn & Retention Analytics Platform
-- File: 01_schema_setup.sql
-- Description: DDL definitions for customer database schema
-- Author: Balayogan C (https://github.com/Balayogan)
-- ====================================================================

-- 1. Customers Core Dimension
CREATE TABLE IF NOT EXISTS dim_customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    gender VARCHAR(10),
    senior_citizen BOOLEAN,
    partner BOOLEAN,
    dependents BOOLEAN,
    signup_date DATE NOT NULL,
    state VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Customer Subscriptions & Contracts
CREATE TABLE IF NOT EXISTS dim_subscriptions (
    subscription_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) REFERENCES dim_customers(customer_id),
    contract_type VARCHAR(20) NOT NULL, -- Month-to-month, One year, Two year
    paperless_billing BOOLEAN,
    payment_method VARCHAR(50) NOT NULL, -- Electronic check, Mailed check, Bank transfer, Credit card
    internet_service VARCHAR(20),        -- DSL, Fiber optic, No
    online_security BOOLEAN,
    tech_support BOOLEAN,
    streaming_tv BOOLEAN,
    streaming_movies BOOLEAN,
    contract_start_date DATE NOT NULL
);

-- 3. Monthly Billing and Usage Facts
CREATE TABLE IF NOT EXISTS fact_monthly_billing (
    billing_id BIGSERIAL PRIMARY KEY,
    customer_id VARCHAR(50) REFERENCES dim_customers(customer_id),
    billing_month DATE NOT NULL,
    tenure_months INT NOT NULL,
    monthly_charges NUMERIC(10, 2) NOT NULL,
    total_charges NUMERIC(12, 2) NOT NULL,
    payment_status VARCHAR(20) DEFAULT 'Paid', -- Paid, Delayed, Failed
    support_tickets_opened INT DEFAULT 0
);

-- 4. Customer Churn Activity Log
CREATE TABLE IF NOT EXISTS fact_churn_events (
    churn_id BIGSERIAL PRIMARY KEY,
    customer_id VARCHAR(50) REFERENCES dim_customers(customer_id),
    churn_date DATE NOT NULL,
    churn_reason VARCHAR(100),
    churn_category VARCHAR(50), -- Competitor, Price, Dissatisfaction, Moved
    clv_at_churn NUMERIC(12, 2)
);

CREATE INDEX idx_billing_customer ON fact_monthly_billing(customer_id);
CREATE INDEX idx_billing_month ON fact_monthly_billing(billing_month);
CREATE INDEX idx_churn_customer ON fact_churn_events(customer_id);
