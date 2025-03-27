import pandas as pd
import os
import glob
import librosa
import numpy as np
import librosa.onset
import librosa.effects
from sklearn.ensemble import RandomForestClassifier, VotingClassifier
from sklearn.metrics import accuracy_score, recall_score, roc_auc_score, confusion_matrix, f1_score
from sklearn.model_selection import train_test_split, GridSearchCV, RandomizedSearchCV
from sklearn.model_selection import StratifiedKFold, LeaveOneGroupOut, GroupKFold, StratifiedGroupKFold
from sklearn.decomposition import PCA
# from sklearn.pipeline import Pipeline
from imblearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.feature_selection import SelectFromModel 
# from sklearn.base import clone
from imblearn.over_sampling import SMOTE, ADASYN
import joblib
from extract_features import extract_features
# from xgboost import XGBClassifier
import json
from tensorflow_decision_forests.keras import RandomForestModel

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
    model = RandomForestClassifier(
        n_estimators=100, 
        max_depth=None,
        min_samples_split=5,
        class_weight='balanced',
        random_state=42
    )

def train_model(X, y, patient_ids, n_splits=5):
    """Train a model with holdout evaluation"""
    print("Total patients:", len(patient_ids))
    print("Class distribution:", y.value_counts())

    # Use LeaveOneGroupOut for better patient-level validation
    logo = LeaveOneGroupOut()

    is_multiclass = len(np.unique(y)) > 2
    # Choose appropriate scoring metric
    scoring = 'f1_weighted' if is_multiclass else 'recall'
    
    # Split into train and test sets while preserving patient groups
    unique_patients = np.unique(patient_ids)
    train_patients, test_patients = train_test_split(
        unique_patients, test_size=0.2, stratify=None, random_state=RANDOM_STATE
    )
    
    # Create masks for train and test data
    train_mask = patient_ids.isin(train_patients)
    test_mask = patient_ids.isin(test_patients)
    
    # Split data
    X_train, X_test = X.loc[train_mask], X.loc[test_mask]
    y_train, y_test = y.loc[train_mask], y.loc[test_mask]
    
    print(f"Training set size: {X_train.shape[0]} samples")
    print(f"Test set size: {X_test.shape[0]} samples")
    print(f"Training class distribution: {y_train.value_counts()}")
    print(f"Test class distribution: {y_test.value_counts()}")
    
    # Define pipeline
    rf_pipeline = Pipeline([
        ('scaler', StandardScaler()),
        ('smote', SMOTE(random_state=RANDOM_STATE)),
        ('classifier', RandomForestClassifier(
            random_state=RANDOM_STATE,
            n_jobs=-1,
            oob_score=True,
            bootstrap=True,
        ))
    ])
    
    # Define parameter grid more like model.py
    param_grid = {
        'classifier__n_estimators': [100, 200],
        'classifier__max_depth': [20, None],
        'classifier__min_samples_split': [5, 8],
        'classifier__min_samples_leaf': [2, 4],
        'classifier__class_weight': ['balanced']
    }
    
    # Create cross-validation splitter for parameter tuning
    cv = StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE)
    
    # Hyperparameter optimization
    print("Optimizing model parameters...")
    search = GridSearchCV(
        rf_pipeline,
        param_grid,
        cv=cv,
        scoring=scoring,
        n_jobs=-1,
        return_train_score=True
    )
    
    # # Apply SMOTE to balance classes
    # print("Applying SMOTE to balance training classes...")
    # try:
    #     smote = SMOTE(random_state=RANDOM_STATE)
    #     X_train_resampled, y_train_resampled = smote.fit_resample(X_train, y_train)
    #     print(f"Class distribution after SMOTE: {np.bincount(y_train_resampled)}")
    # except Exception as e:
    #     print(f"SMOTE failed: {e}. Using original training data.")
    #     X_train_resampled, y_train_resampled = X_train, y_train
    
    # Find best parameters
    search.fit(X_train, y_train, groups=patient_ids[train_mask])
    best_model = search.best_estimator_
    print(f"Best parameters: {search.best_params_}")

    # Export scaler parameters and feature names to JSON
    try:
        scaler = best_model.named_steps['scaler']
        feature_names = X.columns.tolist()
        
        with open("scaler_params.json", "w") as f:
            json.dump({
                "mean": scaler.mean_.tolist(),
                "scale": scaler.scale_.tolist(),
                "feature_names": feature_names
            }, f)
        print("Scaler metadata exported")
        
    except Exception as e:
        print(f"Scaler export failed: {str(e)}")

    try:
        # Convert sklearn model to TF-DF model
        tf_model = RandomForestModel(python_model=best_model.named_steps['classifier'])
        tf_model.save("model.tflite")
        print("Model converted to TFLite")
        
    except Exception as e:
        print(f"TFLite conversion failed: {str(e)}")
    
    # Evaluate on holdout set
    y_pred = best_model.predict(X_test)
    y_proba = best_model.predict_proba(X_test)[:,1]
    
    print("\n=== Final Model Performance on Holdout Set ===")
    print(f"Accuracy: {accuracy_score(y_test, y_pred):.3f}")
    print(f"Sensitivity: {recall_score(y_test, y_pred, pos_label=1):.3f}")
    print(f"Specificity: {recall_score(y_test, y_pred, pos_label=0):.3f}")
    print(f"F1 Score: {f1_score(y_test, y_pred):.3f}")
    print(f"AUC-ROC: {roc_auc_score(y_test, y_proba):.3f}")
    print("\nConfusion Matrix:")
    print(confusion_matrix(y_test, y_pred))

    # Add feature importance analysis like model.py
    feature_importance = pd.DataFrame({
        'Feature': X.columns,
        'Importance': best_model.named_steps['classifier'].feature_importances_
    }).sort_values('Importance', ascending=False)
    
    print("\n=== Top 10 Most Important Features ===")
    print(feature_importance.head(10))

    return best_model

# Main execution
if __name__ == "__main__":
    print("Loading dataset...")
    X, y, patient_ids = load_dataset_with_clinical_data("heart_sounds/", "training_data.csv")
    
    # Train and evaluate the RandomForest model
    best_model = train_model(X, y, patient_ids)
    
    # Save the model
    print("\nSaving model...")
    joblib.dump(best_model, 'heart_sound_model.joblib')
    joblib.dump(X.columns.tolist(), 'feature_names.joblib')

    # Save feature importance
    feature_importance = pd.DataFrame({
            'Feature': X.columns,
            'Importance': best_model.named_steps['classifier'].feature_importances_
        }).sort_values('Importance', ascending=False)

    # Save feature importance for future reference
    feature_importance.to_csv('feature_importance.csv', index=False)
    
    print("\nTraining complete!")