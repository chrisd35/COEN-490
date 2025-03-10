import pandas as pd
import os
import glob
import librosa
import numpy as np
from sklearn.ensemble import RandomForestClassifier  # Changed to ensemble
from sklearn.metrics import accuracy_score, recall_score, roc_auc_score, confusion_matrix
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.model_selection import StratifiedKFold  # Added for class imbalance
from imblearn.over_sampling import SMOTE  # Added for class imbalance
import joblib
from extract_features import extract_features

VALVE_PREFIXES = ["AV", "MV", "PV", "TV"]
cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

def parse_recording_locations(location_str):
    """Handle duplicate valves and normalize casing"""
    locations = location_str.split("+") if pd.notna(location_str) else []
    return list(set([v.strip().upper() for v in locations]))

def load_dataset(audio_dir, labels_csv):
    labels = pd.read_csv(labels_csv)
    
    # Enhanced validation
    if labels["Outcome"].nunique() != 2:
        raise ValueError("Outcome must have exactly 2 classes (Normal/Abnormal)")
    
    features = []
    valid_labels = []
    
    for idx, row in labels.iterrows():
        patient_id = row["Patient ID"]
        recording_locations = parse_recording_locations(row["Recording locations:"])
        patient_features = {}
        
        for valve in recording_locations:
            # Improved file discovery with case insensitivity
            base_pattern = os.path.join(audio_dir, f"{patient_id}_{valve}")
            valve_files = glob.glob(f"{base_pattern}*.wav", recursive=False) + \
                          glob.glob(f"{base_pattern}*.WAV", recursive=False)
            
            # Process multiple recordings per valve
            valve_features = []
            for file_path in valve_files:
                # Add error context to diagnostics
                try:
                    feature_dict = extract_features(file_path,valve)
                    if "error" not in feature_dict:
                        valve_features.append(feature_dict)
                except Exception as e:
                    print(f"Error processing {file_path}: {str(e)}")
            
            if valve_features:
                # Use median instead of mean for robustness
                avg_features = pd.DataFrame(valve_features).median().to_dict()
                for key, value in avg_features.items():
                    patient_features[key] = value
        
        if patient_features:
            features.append(patient_features)
            valid_labels.append(1 if row["Outcome"] == "Abnormal" else 0)

    X = pd.DataFrame(features).fillna(0)
    y = pd.Series(valid_labels)
    
    # Handle class imbalance with SMOTE
    if y.value_counts().min() < 0.2 * len(y):
        print("\nApplying SMOTE for class balance")
        smote = SMOTE(random_state=42)
        X, y = smote.fit_resample(X, y)
    
    return X, y

# Enhanced parameter grid for Random Forest
param_grid = {
    'n_estimators': [50, 100, 200],
    'max_depth': [10, 20, 30, None],
    'min_samples_split': [2, 5, 10],
    'min_samples_leaf': [1, 2, 4],
    'max_features': ['sqrt', 'log2']
}

# Changed to RandomForest with recall scoring
model = GridSearchCV(
    RandomForestClassifier(random_state=42),
    param_grid,
    cv=cv,
    scoring='recall',  # Prioritize sensitivity
    n_jobs=-1  # Enable parallel processing
)

# Load and validate data
try:
    X, y = load_dataset("heart_sounds/", "training_data.csv")
    print("\nClass distribution:", y.value_counts())
    
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, 
        test_size=0.2, 
        stratify=y,
        random_state=42
    )
    
    model.fit(X_train, y_train)
    
    # Enhanced evaluation
    print("\n=== Best Parameters ===")
    print(model.best_params_)
    
    y_pred = model.predict(X_test)
    y_proba = model.predict_proba(X_test)[:,1]
    
    print("\n=== Performance ===")
    print(f"Accuracy: {accuracy_score(y_test, y_pred):.2f}")
    print(f"Sensitivity: {recall_score(y_test, y_pred):.2f}")
    print(f"Specificity: {recall_score(y_test, y_pred, pos_label=0):.2f}")
    print(f"AUC-ROC: {roc_auc_score(y_test, y_proba):.2f}")  # Use probabilities
    print("\nConfusion Matrix:")
    print(confusion_matrix(y_test, y_pred))

except ValueError as ve:
    print(f"\nCritical Data Error: {str(ve)}")
except Exception as e:
    print(f"\nUnexpected Error: {str(e)}")

# Save artifacts only if successful
if 'X' in locals():
    joblib.dump(model.best_estimator_, 'heart_murmur_model.joblib')
    joblib.dump(X.columns.tolist(), 'feature_names.joblib')
    print("\nSaved model and feature names")