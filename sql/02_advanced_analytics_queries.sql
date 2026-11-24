-- ====================================================================
-- Project: Customer Churn & Retention Analytics Platform
-- File: 02_advanced_analytics_queries.sql
-- Description: Advanced analytical queries utilizing CTEs, Window Functions,
--              and Cohort Analysis for business intelligence reporting.
-- Author: Balayogan C (https://github.com/Balayogan)
-- ====================================================================

-- --------------------------------------------------------------------
-- QUERY 1: Monthly Churn Rate & MoM Churn Variance (Window Functions)
-- --------------------------------------------------------------------
WITH monthly_metrics AS (
    SELECT 
        DATE_TRUNC('month', billing_month)::DATE AS billing_period,
        COUNT(DISTINCT customer_id) AS active_subscribers,
        SUM(monthly_charges) AS total_mrr
    FROM fact_monthly_billing
    GROUP BY 1
),
churned_metrics AS (
    SELECT 
        DATE_TRUNC('month', churn_date)::DATE AS churn_period,
        COUNT(DISTINCT customer_id) AS churned_subscribers,
        SUM(clv_at_churn) AS lost_arr_exposure
    FROM fact_churn_events
    GROUP BY 1
)
SELECT 
    m.billing_period,
    m.active_subscribers,
    COALESCE(c.churned_subscribers, 0) AS churned_subscribers,
    ROUND((COALESCE(c.churned_subscribers, 0)::NUMERIC / NULLIF(m.active_subscribers, 0)) * 100, 2) AS churn_rate_pct,
    LAG(ROUND((COALESCE(c.churned_subscribers, 0)::NUMERIC / NULLIF(m.active_subscribers, 0)) * 100, 2), 1) 
        OVER (ORDER BY m.billing_period) AS prev_month_churn_rate_pct,
    ROUND(
        ROUND((COALESCE(c.churned_subscribers, 0)::NUMERIC / NULLIF(m.active_subscribers, 0)) * 100, 2) -
        LAG(ROUND((COALESCE(c.churned_subscribers, 0)::NUMERIC / NULLIF(m.active_subscribers, 0)) * 100, 2), 1) 
            OVER (ORDER BY m.billing_period), 2
    ) AS mom_churn_variance_points,
    COALESCE(c.lost_arr_exposure, 0) AS lost_arr_exposure_usd
FROM monthly_metrics m
LEFT JOIN churned_metrics c ON m.billing_period = c.churn_period
ORDER BY m.billing_period DESC;


-- --------------------------------------------------------------------
-- QUERY 2: Cohort Retention Analysis (Tenure Milestones)
-- --------------------------------------------------------------------
WITH customer_cohorts AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', signup_date)::DATE AS cohort_month
    FROM dim_customers
),
activity_logs AS (
    SELECT 
        b.customer_id,
        c.cohort_month,
        b.tenure_months,
        ROW_NUMBER() OVER (PARTITION BY b.customer_id ORDER BY b.tenure_months) AS rn
    FROM fact_monthly_billing b
    JOIN customer_cohorts c ON b.customer_id = c.customer_id
)
SELECT 
    cohort_month,
    COUNT(DISTINCT customer_id) AS cohort_size,
    COUNT(DISTINCT CASE WHEN tenure_months >= 3 THEN customer_id END) AS retained_month_3,
    COUNT(DISTINCT CASE WHEN tenure_months >= 6 THEN customer_id END) AS retained_month_6,
    COUNT(DISTINCT CASE WHEN tenure_months >= 12 THEN customer_id END) AS retained_month_12,
    ROUND((COUNT(DISTINCT CASE WHEN tenure_months >= 6 THEN customer_id END)::NUMERIC / COUNT(DISTINCT customer_id)) * 100, 1) AS m6_retention_rate_pct,
    ROUND((COUNT(DISTINCT CASE WHEN tenure_months >= 12 THEN customer_id END)::NUMERIC / COUNT(DISTINCT customer_id)) * 100, 1) AS m12_retention_rate_pct
FROM activity_logs
GROUP BY cohort_month
ORDER BY cohort_month ASC;


-- --------------------------------------------------------------------
-- QUERY 3: High-Value At-Risk Customer Identification (Prioritized for Outreach)
-- --------------------------------------------------------------------
WITH customer_aggregates AS (
    SELECT 
        c.customer_id,
        c.state,
        s.contract_type,
        s.payment_method,
        s.tech_support,
        MAX(b.tenure_months) AS latest_tenure,
        AVG(b.monthly_charges) AS avg_monthly_spend,
        MAX(b.total_charges) AS total_clv_to_date,
        SUM(b.support_tickets_opened) AS total_support_tickets,
        COUNT(CASE WHEN b.payment_status = 'Failed' THEN 1 END) AS failed_payments_count,
        NTILE(4) OVER (ORDER BY AVG(b.monthly_charges) DESC) AS revenue_quartile
    FROM dim_customers c
    JOIN dim_subscriptions s ON c.customer_id = s.customer_id
    JOIN fact_monthly_billing b ON c.customer_id = b.customer_id
    WHERE c.customer_id NOT IN (SELECT customer_id FROM fact_churn_events)
    GROUP BY c.customer_id, c.state, s.contract_type, s.payment_method, s.tech_support
)
SELECT 
    customer_id,
    state,
    contract_type,
    latest_tenure,
    ROUND(avg_monthly_spend, 2) AS avg_monthly_spend,
    ROUND(total_clv_to_date, 2) AS total_revenue_generated,
    total_support_tickets,
    failed_payments_count,
    CASE 
        WHEN contract_type = 'Month-to-month' AND total_support_tickets >= 3 AND revenue_quartile = 1 THEN 'CRITICAL RISK - Top Tier ARR'
        WHEN contract_type = 'Month-to-month' AND (total_support_tickets >= 2 OR failed_payments_count >= 1) THEN 'HIGH RISK'
        WHEN contract_type = 'One year' AND total_support_tickets >= 4 THEN 'MODERATE RISK'
        ELSE 'LOW RISK'
    END AS retention_priority_tier
FROM customer_aggregates
WHERE contract_type = 'Month-to-month' AND (total_support_tickets >= 2 OR failed_payments_count >= 1)
ORDER BY avg_monthly_spend DESC, total_support_tickets DESC
LIMIT 50;


-- --------------------------------------------------------------------
-- QUERY 4: Churn Drivers by Contract Type & Payment Channel
-- --------------------------------------------------------------------
SELECT 
    s.contract_type,
    s.payment_method,
    COUNT(DISTINCT c.customer_id) AS total_accounts,
    COUNT(DISTINCT ch.customer_id) AS churned_accounts,
    ROUND((COUNT(DISTINCT ch.customer_id)::NUMERIC / COUNT(DISTINCT c.customer_id)) * 100, 2) AS segment_churn_rate_pct,
    ROUND(AVG(b.monthly_charges), 2) AS avg_monthly_charges,
    ROUND(SUM(CASE WHEN ch.customer_id IS NOT NULL THEN b.monthly_charges * 12 ELSE 0 END), 2) AS annualized_lost_revenue
FROM dim_customers c
JOIN dim_subscriptions s ON c.customer_id = s.customer_id
JOIN fact_monthly_billing b ON c.customer_id = b.customer_id
LEFT JOIN fact_churn_events ch ON c.customer_id = ch.customer_id
GROUP BY s.contract_type, s.payment_method
ORDER BY segment_churn_rate_pct DESC;
