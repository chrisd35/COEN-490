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
from sklearn.model_selection import StratifiedKFold, LeaveOneGroupOut, GroupKFold, StratifiedGroupKFold
from sklearn.decomposition import PCA
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.feature_selection import SelectFromModel 
from sklearn.base import clone
from imblearn.over_sampling import SMOTE, ADASYN
import joblib
from extract_features import extract_features
from xgboost import XGBClassifier

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

def evaluate_with_kfold(X, y, patient_ids, n_splits=5, n_components=0.95):
    """Evaluate model with stratified k-fold cross-validation while respecting patient groups"""
    
    print("Class distribution in full dataset:", np.bincount(y))
    
    # Use StratifiedGroupKFold for better class balance preservation
    group_kfold = StratifiedGroupKFold(n_splits=n_splits)
    
    metrics = {'accuracy': [], 'sensitivity': [], 'specificity': [], 'auc': []}
    
    # Create pipeline with XGBoost
    pipeline = Pipeline([
        ('scaler', StandardScaler()),
        ('feature_selection', SelectFromModel(XGBClassifier(importance_type='gain'))),
        ('classifier', XGBClassifier(random_state=RANDOM_STATE, eval_metric='logloss', scale_pos_weight=np.sum(y == 0)/np.sum(y == 1)))
    ])
    
    # Enhanced parameter grid
    param_grid = {
        'classifier__n_estimators': [200, 400, 800],  
        'classifier__max_depth': [3, 6, 9, 12],       
        'classifier__learning_rate': [0.001, 0.01, 0.1, 0.2],  
        'classifier__subsample': [0.6, 0.7, 0.8, 1.0],
        'classifier__colsample_bytree': [0.6, 0.7, 0.8, 1.0],
        'classifier__gamma': [0, 0.1, 0.2, 0.5],      
        'classifier__min_child_weight': [1, 3, 5]     
}
    
    # Use GroupShuffleSplit for hyperparameter search
    search = RandomizedSearchCV(
        pipeline,
        param_grid,
        n_iter=50,
        cv=GroupKFold(n_splits=3),
        scoring='roc_auc',
        n_jobs=-1,
        random_state=RANDOM_STATE
    )
    search.fit(X, y, groups=patient_ids)
    best_params = search.best_params_
    best_pipeline = search.best_estimator_
    
    # Cross-validation loop
    for train_idx, test_idx in group_kfold.split(X, y, groups=patient_ids):
        X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
        y_train, y_test = y.iloc[train_idx], y.iloc[test_idx]
        
        # Handle class imbalance with safe resampling
        class_counts = np.bincount(y_train)
        print(f"\nFold class distribution - Train: {class_counts}, Test: {np.bincount(y_test)}")
        
        try:
            if len(class_counts) < 2 or min(class_counts) < 5:
                print("Insufficient samples for resampling, using original distribution")
                X_res, y_res = X_train, y_train
            else:
                # Dynamic k_neighbors based on minority class size
                safe_k = max(1, min(3, class_counts[1] - 1)) if class_counts[1] < class_counts[0] else max(1, min(3, class_counts[0] - 1))
                
                smote = SMOTE(
                    sampling_strategy='auto',
                    k_neighbors=safe_k,
                    random_state=RANDOM_STATE
                )
                X_res, y_res = smote.fit_resample(X_train, y_train)
                print(f"Resampled class distribution: {np.bincount(y_res)}")
                
        except ValueError as e:
            print(f"Resampling failed: {str(e)}, using original data")
            X_res, y_res = X_train, y_train

        # Clone and fit model
        model = clone(best_pipeline)
        model.fit(X_res, y_res)
        
        # Generate predictions
        y_pred = model.predict(X_test)
        y_proba = model.predict_proba(X_test)[:, 1]
        
        # Calculate metrics
        metrics['accuracy'].append(accuracy_score(y_test, y_pred))
        metrics['sensitivity'].append(recall_score(y_test, y_pred, pos_label=1, zero_division=0))
        metrics['specificity'].append(recall_score(y_test, y_pred, pos_label=0, zero_division=0))
        if len(np.unique(y_test)) > 1:
            metrics['auc'].append(roc_auc_score(y_test, y_proba))
    
    # Print results
    print("\n=== XGBoost Validation Results ===")
    print(f"Best parameters: {best_params}")
    for metric, values in metrics.items():
        print(f"{metric.capitalize()}: {np.nanmean(values):.3f} ± {np.nanstd(values):.3f}")
    
    return metrics, best_pipeline

def train_final_model(X, y, best_pipeline=None):
    """Train final model with full data using safe resampling"""
    print("\n=== Final Model Training ===")
    print("Initial class distribution:", np.bincount(y))
    
    # Safe resampling logic
    class_counts = np.bincount(y)
    try:
        if len(class_counts) < 2 or min(class_counts) < 5:
            print("Insufficient samples for resampling, using original data")
            X_res, y_res = X, y
        else:
            safe_k = max(1, min(3, class_counts[1]-1)) if class_counts[1] < class_counts[0] else max(1, min(3, class_counts[0]-1))
            smote = SMOTE(
                sampling_strategy='auto',
                k_neighbors=safe_k,
                random_state=RANDOM_STATE
            )
            X_res, y_res = smote.fit_resample(X, y)
            print(f"Resampled class distribution: {np.bincount(y_res)}")
            
    except ValueError as e:
        print(f"Resampling failed: {str(e)}, using original data")
        X_res, y_res = X, y

    if best_pipeline is not None:
        model = clone(best_pipeline)
    else:
        model = Pipeline([
            ('scaler', StandardScaler()),
            ('classifier', XGBClassifier(
                random_state=RANDOM_STATE,
                eval_metric='logloss',
                scale_pos_weight=np.sum(y == 0)/np.sum(y == 1)
            ))
        ])
    
    model.fit(X_res, y_res)
    return model

# Main execution
if __name__ == "__main__":
    X, y, patient_ids = load_dataset_with_clinical_data("heart_sounds/", "training_data.csv")
    
    # 1. Cross-validated evaluation
    metrics, best_pipeline = evaluate_with_kfold(X, y, patient_ids, n_splits=5)
    
    # 2. Train final model using the best pipeline
    final_model = train_final_model(X, y, best_pipeline)
    joblib.dump(final_model, 'heart_sound_model.joblib')
    joblib.dump(X.columns.tolist(), 'feature_names.joblib')
    print("\nSaved trained heart sound ML model")
    
    # Optional: Print the number of components used
    if hasattr(final_model, 'named_steps') and 'pca' in final_model.named_steps:
        n_components = final_model.named_steps['pca'].n_components_
        explained_variance = final_model.named_steps['pca'].explained_variance_ratio_.sum()
        print(f"Number of PCA components used: {n_components}")
        print(f"Explained variance: {explained_variance:.2%}")