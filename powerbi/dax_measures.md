# Power BI DAX Measures & Data Model Documentation
**Project:** Customer Churn & Retention Analytics Platform  
**Author:** Balayogan C ([GitHub](https://github.com/Balayogan))

---

## 1. Data Model Architecture (Star Schema)
```
          +-----------------------+
          |     dim_calendar      |
          +-----------------------+
                     |
                     | (1:*)
                     v
+------------------+ (1:*) +------------------------+
|  dim_customers   |<----->| fact_churn_predictions |
+------------------+       +------------------------+
                     ^
                     | (1:*)
          +-----------------------+
          |   dim_subscriptions   |
          +-----------------------+
```

---

## 2. Core Business DAX Calculations

### Measure 1: Total Customer Count
```dax
Total Customers = DISTINCTCOUNT(fact_churn_predictions[CustomerID])
```

### Measure 2: Active Customer Count
```dax
Active Customers = 
CALCULATE(
    [Total Customers],
    fact_churn_predictions[Churn] = "No"
)
```

### Measure 3: Churned Customer Count
```dax
Churned Customers = 
CALCULATE(
    [Total Customers],
    fact_churn_predictions[Churn] = "Yes"
)
```

### Measure 4: Churn Rate %
```dax
Churn Rate % = 
DIVIDE([Churned Customers], [Total Customers], 0)
```

### Measure 5: Monthly Recurring Revenue (MRR)
```dax
Total MRR = SUM(fact_churn_predictions[MonthlyCharges])
```

### Measure 6: Annual Recurring Revenue (ARR) Exposure at Risk
```dax
At-Risk ARR Exposure = 
CALCULATE(
    SUM(fact_churn_predictions[AtRiskRevenueExposure]),
    fact_churn_predictions[RiskCategory] IN {"Tier 1 - Critical Risk", "Tier 2 - High Risk"}
)
```

### Measure 7: Customer Lifetime Value (CLV)
```dax
Average CLV = AVERAGE(fact_churn_predictions[TotalCharges])
```

### Measure 8: Average Customer Tenure (Months)
```dax
Avg Tenure Months = AVERAGE(fact_churn_predictions[Tenure])
```

### Measure 9: High-Risk Customer Ratio %
```dax
Critical Risk Ratio % = 
VAR CriticalCount = CALCULATE([Total Customers], fact_churn_predictions[RiskCategory] = "Tier 1 - Critical Risk")
RETURN
DIVIDE(CriticalCount, [Total Customers], 0)
```

### Measure 10: MoM Churn Variance
```dax
MoM Churn Variance = 
VAR CurrentMonthChurn = [Churn Rate %]
VAR PreviousMonthChurn = 
    CALCULATE(
        [Churn Rate %], 
        DATEADD(dim_calendar[Date], -1, MONTH)
    )
RETURN
CurrentMonthChurn - PreviousMonthChurn
```

---

## 3. Executive Dashboard Layout Structure
- **Top KPI Cards:** Active Accounts, Churn Rate %, Total MRR ($), At-Risk ARR ($), Average Tenure.
- **Visual 1 (Donut Chart):** Customer Distribution by Risk Tier (Critical, High, Moderate, Safe).
- **Visual 2 (Bar Chart):** Churn Rate by Contract Type (Month-to-Month vs One-Year vs Two-Year).
- **Visual 3 (Scatter Plot):** Monthly Spend vs Tenure colored by Churn Probability.
- **Visual 4 (Table / Matrix):** Prioritized At-Risk Accounts (CustomerID, Contract, Support Tickets, Churn Probability, Revenue at Risk, Action Recommended).
