import pandas as pd
import os
import glob
import librosa
import numpy as np
import librosa.onset
import librosa.effects
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, recall_score, roc_auc_score, confusion_matrix, f1_score
from sklearn.model_selection import train_test_split, GridSearchCV, RandomizedSearchCV
from sklearn.model_selection import StratifiedKFold, LeaveOneGroupOut
from sklearn.pipeline import Pipeline
from imblearn.over_sampling import SMOTE
import joblib
from extract_features import extract_features
# from xgboost import XGBClassifier

# Define standard valve prefixes
VALVE_PREFIXES = ["AV", "MV", "PV", "TV"]  # Aortic, Mitral, Pulmonary, Tricuspid
RANDOM_STATE = 42

def parse_recording_locations(location_str):
    """Handle duplicate valves and normalize casing"""
    locations = location_str.split("+") if pd.notna(location_str) else []
    return list(set([v.strip().upper() for v in locations]))

def load_dataset_with_clinical_data(audio_dir, labels_csv):
    labels = pd.read_csv(labels_csv)
    features = []
    valid_labels = []
    patient_groups = []
    
    for idx, row in labels.iterrows():
        patient_id = row["Patient ID"]
        recording_locations = parse_recording_locations(row["Recording locations:"])
        
        for valve in recording_locations:
            base_pattern = os.path.join(audio_dir, f"{patient_id}_{valve}")
            valve_files = glob.glob(f"{base_pattern}*.wav") + glob.glob(f"{base_pattern}*.WAV")
            
            for file_path in valve_files:
                try:
                    # Directly use centralized feature extraction
                    feature_dict, _ = extract_features(file_path)
                    
                    if "error" not in feature_dict:
                        features.append(feature_dict)
                        valid_labels.append(1 if row["Outcome"] == "Abnormal" else 0)
                        patient_groups.append(patient_id)
                except Exception as e:
                    print(f"Error processing {file_path}: {str(e)}")

    X = pd.DataFrame(features).fillna(0)
    y = pd.Series(valid_labels)
    return X, y, pd.Series(patient_groups)

def evaluate_with_leave_one_patient_out(X, y, patient_ids):
    """Evaluate model with leave-one-patient-out cross-validation"""
    logo = LeaveOneGroupOut()

    # Hyperparameter grid for tuning
    param_grid = {
        'n_estimators': [100, 200, 300],
        'max_depth': [None, 10, 20],
        'min_samples_split': [2, 5, 10]
    }
    
    metrics = {'accuracy': [], 'sensitivity': [], 'specificity': [], 'auc': []}
    
    for train_idx, test_idx in logo.split(X, y, groups=patient_ids):
        X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
        y_train, y_test = y.iloc[train_idx], y.iloc[test_idx]
        
        # Handle class imbalance with SMOTE
        smote = SMOTE(random_state=RANDOM_STATE)
        X_res, y_res = smote.fit_resample(X_train, y_train)
        
        # Hyperparameter search within each fold
        rf = RandomForestClassifier(class_weight='balanced', random_state=RANDOM_STATE)
        search = RandomizedSearchCV(rf, param_grid, n_iter=10, cv=3, n_jobs=-1)
        search.fit(X_res, y_res)
        
        # Get best model from search
        best_model = search.best_estimator_
        y_pred = best_model.predict(X_test)
        y_proba = best_model.predict_proba(X_test)[:, 1]
        
        # Update metrics
        metrics['accuracy'].append(accuracy_score(y_test, y_pred))
        metrics['sensitivity'].append(recall_score(y_test, y_pred, pos_label=1))
        metrics['specificity'].append(recall_score(y_test, y_pred, pos_label=0))
        if len(np.unique(y_test)) > 1:
            metrics['auc'].append(roc_auc_score(y_test, y_proba))
    
    # Print results
    print("\n=== Random Forest Validation ===")
    for metric, values in metrics.items():
        print(f"{metric.capitalize()}: {np.nanmean(values):.3f} ± {np.nanstd(values):.3f}")
    
    return metrics

def train_final_model(X, y):
    """Train final model with full data"""
    smote = SMOTE(random_state=RANDOM_STATE)
    X_res, y_res = smote.fit_resample(X, y)
    
    model = RandomForestClassifier(
        n_estimators=200,
        max_depth=None,
        min_samples_split=5,
        class_weight='balanced',
        random_state=RANDOM_STATE
    )
    model.fit(X_res, y_res)
    return model

# Main execution
if __name__ == "__main__":
    X, y, patient_ids = load_dataset_with_clinical_data("heart_sounds/", "training_data.csv")
    
    # 1. Cross-validated evaluation
    evaluate_with_leave_one_patient_out(X, y, patient_ids)
    
    # 2. Train final model
    final_model = train_final_model(X, y)
    joblib.dump(final_model, 'random_forest_model.joblib')
    print("\nSaved trained Random Forest model")