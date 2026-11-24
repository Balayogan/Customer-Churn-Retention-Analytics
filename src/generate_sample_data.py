"""
Project: Customer Churn & Retention Analytics Platform
File: generate_sample_data.py
Description: Generates a realistic synthetic customer dataset (5,000 records)
             mirroring real-world telecommunications/SaaS subscription patterns.
Author: Balayogan C (https://github.com/Balayogan)
"""

import os
import numpy as np
import pandas as pd

def generate_customer_churn_dataset(n_samples=5000, random_seed=42):
    np.random.seed(random_seed)
    
    customer_ids = [f"CUST-{10000 + i}" for i in range(n_samples)]
    genders = np.random.choice(["Male", "Female"], size=n_samples, p=[0.5, 0.5])
    senior_citizens = np.random.choice([0, 1], size=n_samples, p=[0.84, 0.16])
    partners = np.random.choice(["Yes", "No"], size=n_samples, p=[0.48, 0.52])
    dependents = np.random.choice(["Yes", "No"], size=n_samples, p=[0.30, 0.70])
    
    # Tenure in months (skewed towards new customers with higher early churn)
    tenures = np.random.exponential(scale=24, size=n_samples).astype(int)
    tenures = np.clip(tenures, 1, 72)
    
    # Contract Types
    contract_choices = ["Month-to-month", "One year", "Two year"]
    contract_probs = [0.55, 0.25, 0.20]
    contracts = np.random.choice(contract_choices, size=n_samples, p=contract_probs)
    
    # Internet Services
    internet_services = np.random.choice(["Fiber optic", "DSL", "No"], size=n_samples, p=[0.44, 0.34, 0.22])
    
    # Payment Methods
    payment_methods = np.random.choice(
        ["Electronic check", "Mailed check", "Bank transfer", "Credit card"],
        size=n_samples,
        p=[0.34, 0.22, 0.22, 0.22]
    )
    
    # Monthly Charges
    base_charges = {"Fiber optic": 85.0, "DSL": 55.0, "No": 22.0}
    monthly_charges = np.array([
        np.random.normal(loc=base_charges[service], scale=12.0)
        for service in internet_services
    ])
    monthly_charges = np.round(np.clip(monthly_charges, 18.5, 118.75), 2)
    
    # Total Charges
    total_charges = np.round(monthly_charges * tenures + np.random.normal(0, 5, n_samples), 2)
    total_charges = np.maximum(total_charges, monthly_charges)
    
    # Support tickets
    support_tickets = np.random.poisson(lam=1.2, size=n_samples)
    
    # Churn probability based on realistic risk factors:
    # High risk: Month-to-month, Fiber optic, Electronic check, High monthly charges, Short tenure, Many support tickets
    log_odds = (
        -1.5
        + 1.8 * (contracts == "Month-to-month")
        - 1.4 * (contracts == "Two year")
        + 0.9 * (payment_methods == "Electronic check")
        + 0.8 * (internet_services == "Fiber optic")
        + 0.015 * monthly_charges
        - 0.045 * tenures
        + 0.45 * support_tickets
        + 0.35 * senior_citizens
    )
    probabilities = 1 / (1 + np.exp(-log_odds))
    churn_flags = np.random.binomial(1, probabilities)
    churn = ["Yes" if c == 1 else "No" for c in churn_flags]
    
    df = pd.DataFrame({
        "CustomerID": customer_ids,
        "Gender": genders,
        "SeniorCitizen": senior_citizens,
        "Partner": partners,
        "Dependents": dependents,
        "Tenure": tenures,
        "Contract": contracts,
        "InternetService": internet_services,
        "PaymentMethod": payment_methods,
        "MonthlyCharges": monthly_charges,
        "TotalCharges": total_charges,
        "SupportTickets": support_tickets,
        "Churn": churn
    })
    
    return df

if __name__ == "__main__":
    os.makedirs("data", exist_ok=True)
    df = generate_customer_churn_dataset(n_samples=5000)
    output_path = os.path.join("data", "customer_churn_data.csv")
    df.to_csv(output_path, index=False)
    print(f"[SUCCESS] Generated {len(df):,} customer records saved to '{output_path}'.")
    print(f"Overall Churn Rate: {(df['Churn'] == 'Yes').mean() * 100:.2f}%")
