"""
Project: Customer Churn & Retention Analytics Platform
File: churn_pipeline.py
Description: End-to-end data processing, feature engineering, model training,
             and scoring pipeline for customer retention decision-support.
Author: Balayogan C (https://github.com/Balayogan)
"""

import os
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import classification_report, roc_auc_score, f1_score, confusion_matrix

def run_churn_pipeline(data_path="data/customer_churn_data.csv"):
    print("[1/5] Loading customer data...")
    if not os.path.exists(data_path):
        from generate_sample_data import generate_customer_churn_dataset
        df = generate_customer_churn_dataset(n_samples=5000)
        os.makedirs(os.path.dirname(data_path), exist_ok=True)
        df.to_csv(data_path, index=False)
    else:
        df = pd.read_csv(data_path)
        
    print(f"Dataset Shape: {df.shape[0]} rows, {df.shape[1]} columns")
    print(f"Baseline Churn Rate: {(df['Churn'] == 'Yes').mean() * 100:.2f}%\n")
    
    # 2. Feature Engineering & Preprocessing
    print("[2/5] Performing feature engineering...")
    df['TenureYears'] = np.round(df['Tenure'] / 12, 1)
    df['AvgMonthlySpend'] = np.round(df['TotalCharges'] / np.maximum(df['Tenure'], 1), 2)
    df['HighSupportRisk'] = (df['SupportTickets'] >= 3).astype(int)
    
    target_col = 'Churn'
    X = df.drop(columns=['CustomerID', target_col])
    y = (df[target_col] == 'Yes').astype(int)
    
    numeric_features = ['Tenure', 'MonthlyCharges', 'TotalCharges', 'SupportTickets', 'AvgMonthlySpend']
    categorical_features = ['Gender', 'Partner', 'Dependents', 'Contract', 'InternetService', 'PaymentMethod']
    
    preprocessor = ColumnTransformer(
        transformers=[
            ('num', StandardScaler(), numeric_features),
            ('cat', OneHotEncoder(drop='first', sparse_output=False), categorical_features)
        ]
    )
    
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.20, random_state=42, stratify=y
    )
    
    # 3. Model Training & Comparison
    print("[3/5] Training predictive classifiers (Logistic Regression, Random Forest, Gradient Boosting)...")
    models = {
        "Logistic Regression": LogisticRegression(max_iter=1000, random_state=42),
        "Random Forest": RandomForestClassifier(n_estimators=150, max_depth=8, random_state=42),
        "Gradient Boosting (XGBoost Benchmark)": GradientBoostingClassifier(n_estimators=120, learning_rate=0.08, max_depth=4, random_state=42)
    }
    
    best_model_name = None
    best_auc = 0.0
    best_pipeline = None
    
    results = []
    for name, clf in models.items():
        pipeline = Pipeline(steps=[('preprocessor', preprocessor), ('classifier', clf)])
        pipeline.fit(X_train, y_train)
        
        y_pred = pipeline.predict(X_test)
        y_prob = pipeline.predict_proba(X_test)[:, 1]
        
        auc = roc_auc_score(y_test, y_prob)
        f1 = f1_score(y_test, y_pred)
        
        results.append({
            "Model": name,
            "ROC-AUC": round(auc, 4),
            "F1-Score": round(f1, 4)
        })
        
        if auc > best_auc:
            best_auc = auc
            best_model_name = name
            best_pipeline = pipeline
            
    print("\n--- Model Benchmark Results ---")
    results_df = pd.DataFrame(results)
    print(results_df.to_string(index=False))
    print(f"\n[4/5] Selected Best Model: '{best_model_name}' (ROC-AUC: {best_auc:.4f})")
    
    # 4. Score Entire Customer Base for Power BI Dashboard
    print("[5/5] Scoring all accounts and exporting Power BI dataset...")
    all_probs = best_pipeline.predict_proba(X)[:, 1]
    df['ChurnProbability'] = np.round(all_probs, 4)
    
    # Assign Risk Tiers
    conditions = [
        (df['ChurnProbability'] >= 0.70),
        (df['ChurnProbability'] >= 0.45) & (df['ChurnProbability'] < 0.70),
        (df['ChurnProbability'] >= 0.20) & (df['ChurnProbability'] < 0.45),
        (df['ChurnProbability'] < 0.20)
    ]
    tiers = ['Tier 1 - Critical Risk', 'Tier 2 - High Risk', 'Tier 3 - Moderate Risk', 'Tier 4 - Safe']
    df['RiskCategory'] = np.select(conditions, tiers)
    df['AtRiskRevenueExposure'] = np.where(df['ChurnProbability'] >= 0.45, df['MonthlyCharges'] * 12, 0.0)
    
    output_scored_path = "data/churn_scored_predictions.csv"
    df.to_csv(output_scored_path, index=False)
    print(f"[SUCCESS] Scored dataset saved to '{output_scored_path}' for Power BI ingestion.")
    
    # Summary of exposure
    critical_arr = df[df['RiskCategory'] == 'Tier 1 - Critical Risk']['AtRiskRevenueExposure'].sum()
    print(f"Total High-Risk Customer ARR Exposure: ${critical_arr:,.2f}")
    
if __name__ == "__main__":
    run_churn_pipeline()
