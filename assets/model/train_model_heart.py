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

def train_model(X, y, patient_ids, n_splits=5):
    """
    Train an ensemble model with proper cross-validation, hyperparameter optimization,
    and consistent feature selection across all base models.
    
    Parameters:
    -----------
    X : pandas.DataFrame
        Feature matrix
    y : pandas.Series
        Target variable
    patient_ids : pandas.Series
        Patient identifiers for group-based splitting
    n_splits : int, default=5
        Number of cross-validation splits
    
    Returns:
    --------
    ensemble : Trained ensemble model
    performance_metrics : dict
        Dictionary of model performance metrics
    """
        
    # Create cross-validation splitter that respects patient groups
    group_kfold = StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=RANDOM_STATE)
    
    # Define feature selector to ensure consistency across models
    # This will be fitted once and reused for all models
    feature_selector = SelectFromModel(
        XGBClassifier(importance_type='gain', random_state=RANDOM_STATE),
        threshold=-np.inf,  # Select all features initially
        max_features=None  # Will be tuned later
    )
    
    # Define base models with parameter grids
    base_models = {
        'xgb': {
            'model': Pipeline([
                ('scaler', StandardScaler()),
                ('feature_selection', 'passthrough'),  # Placeholder for feature selector
                ('classifier', XGBClassifier(random_state=RANDOM_STATE, scale_pos_weight=np.sum(y == 0)/np.sum(y == 1)))
            ]),
            'param_grid': {
                'classifier__n_estimators': [400, 800],
                'classifier__max_depth': [3, 4],
                'classifier__learning_rate': [0.005, 0.01],
                'classifier__subsample': [0.8, 0.9],
                'classifier__colsample_bytree': [0.8, 0.9],
                'classifier__min_child_weight': [3, 5],
                'classifier__gamma': [0.1, 0.2]
            }
        },
        'rf': {
            'model': Pipeline([
                ('scaler', StandardScaler()),
                ('feature_selection', 'passthrough'),  # Placeholder for feature selector
                ('classifier', RandomForestClassifier(
                    random_state=RANDOM_STATE,
                    class_weight='balanced'))
            ]),
            'param_grid': {
                'classifier__n_estimators': [200, 400],
                'classifier__max_depth': [4, 6],
                'classifier__min_samples_split': [5, 10],
                'classifier__min_samples_leaf': [2, 4],
                'classifier__max_features': ['sqrt', 'log2', None]
            }
        }
    }
    
    # Feature selection optimization
    print("Optimizing feature selection...")
    n_features = X.shape[1]
    max_features_options = [15, 20, 25, 30, None]
    # Filter options based on actual feature count
    max_features_options = [x for x in max_features_options if x is None or x <= n_features]
    feature_selection_cv = RandomizedSearchCV(
        Pipeline([
            ('scaler', StandardScaler()),
            ('feature_selection', SelectFromModel(
                XGBClassifier(importance_type='gain', random_state=RANDOM_STATE),
                threshold=-np.inf
            )),
            ('classifier', XGBClassifier(random_state=RANDOM_STATE))
        ]),
        {
            'feature_selection__max_features': max_features_options,
            'classifier__n_estimators': [100, 200],
            'classifier__max_depth': [3, 5]
        },
        n_iter=10,
        cv=group_kfold,
        scoring='roc_auc',
        random_state=RANDOM_STATE
    )
    feature_selection_cv.fit(X, y, groups=patient_ids)
    optimal_features = feature_selection_cv.best_params_['feature_selection__max_features']
    print(f"Optimal feature count: {optimal_features}")
    
    # Define and fit the feature selector
    feature_selector = SelectFromModel(
        XGBClassifier(importance_type='gain', random_state=RANDOM_STATE),
        max_features=optimal_features
    )
    feature_selector.fit(X, y)
    
    # Train optimized base models
    best_models = {}
    model_performances = {}
    
    for name, model_config in base_models.items():
        print(f"\nTraining {name} model...")
        
        # Update model's feature selection step
        model_config['model'].steps[1] = ('feature_selection', clone(feature_selector))
        
        # Hyperparameter optimization
        search = RandomizedSearchCV(
            model_config['model'],
            model_config['param_grid'],
            n_iter=30,
            cv=group_kfold,
            scoring='roc_auc',
            n_jobs=-1,
            random_state=RANDOM_STATE,
            verbose=1
        )
        search.fit(X, y, groups=patient_ids)
        
        best_models[name] = search.best_estimator_
        print(f"Best {name} params: {search.best_params_}")
        
        # Cross-validation evaluation
        cv_metrics = {'accuracy': [], 'sensitivity': [], 'specificity': [], 'auc': [], 'f1': []}
        
        for train_idx, test_idx in group_kfold.split(X, y, groups=patient_ids):
            X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
            y_train, y_test = y.iloc[train_idx], y.iloc[test_idx]
            
            # Handle class imbalance
            class_counts = np.bincount(y_train)
            if len(class_counts) > 1 and min(class_counts) >= 5:
                # Dynamic k_neighbors based on minority class size
                safe_k = max(1, min(5, min(class_counts) - 1))
                smote = SMOTE(k_neighbors=safe_k, random_state=RANDOM_STATE)
                X_train, y_train = smote.fit_resample(X_train, y_train)
            
            # Train and evaluate
            model = clone(best_models[name])
            model.fit(X_train, y_train)
            
            y_pred = model.predict(X_test)
            y_proba = model.predict_proba(X_test)[:, 1]
            
            cv_metrics['accuracy'].append(accuracy_score(y_test, y_pred))
            cv_metrics['sensitivity'].append(recall_score(y_test, y_pred, pos_label=1, zero_division=0))
            cv_metrics['specificity'].append(recall_score(y_test, y_pred, pos_label=0, zero_division=0))
            cv_metrics['f1'].append(f1_score(y_test, y_pred, zero_division=0))
            
            if len(np.unique(y_test)) > 1:
                cv_metrics['auc'].append(roc_auc_score(y_test, y_proba))
        
        model_performances[name] = {metric: np.mean(values) for metric, values in cv_metrics.items()}
        print(f"{name} performance: {model_performances[name]}")
    
    # Create and optimize voting ensemble
    print("\nTraining voting ensemble...")
    
    # Define potential voting weights based on model performances
    auc_weights = []
    for model_name in best_models.keys():
        auc = model_performances[model_name].get('auc', 0)
        auc_weights.append(max(0.1, auc))  # Ensure minimum weight
    
    # Normalize weights
    if sum(auc_weights) > 0:
        auc_weights = [w/sum(auc_weights) for w in auc_weights]
    else:
        auc_weights = [1/len(auc_weights)] * len(auc_weights)
    
    # Create ensemble with optimized weights
    ensemble = VotingClassifier(
        estimators=[(name, model) for name, model in best_models.items()],
        voting='soft',
        weights=auc_weights
    )
    
    # Final training on full dataset
    # Resampling to handle imbalance
    try:
        smote = SMOTE(random_state=RANDOM_STATE)
        X_res, y_res = smote.fit_resample(X, y)
    except ValueError:
        print("SMOTE failed, using original data")
        X_res, y_res = X, y
    
    ensemble.fit(X_res, y_res)
    
    # Evaluate ensemble with cross-validation
    ensemble_metrics = {'accuracy': [], 'sensitivity': [], 'specificity': [], 'auc': [], 'f1': []}
    
    for train_idx, test_idx in group_kfold.split(X, y, groups=patient_ids):
        X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
        y_train, y_test = y.iloc[train_idx], y.iloc[test_idx]
        
        # Handle class imbalance
        try:
            smote = SMOTE(random_state=RANDOM_STATE)
            X_train, y_train = smote.fit_resample(X_train, y_train)
        except ValueError:
            pass
        
        # Train and evaluate
        ensemble_cv = clone(ensemble)
        ensemble_cv.fit(X_train, y_train)
        
        y_pred = ensemble_cv.predict(X_test)
        y_proba = ensemble_cv.predict_proba(X_test)[:, 1]
        
        ensemble_metrics['accuracy'].append(accuracy_score(y_test, y_pred))
        ensemble_metrics['sensitivity'].append(recall_score(y_test, y_pred, pos_label=1, zero_division=0))
        ensemble_metrics['specificity'].append(recall_score(y_test, y_pred, pos_label=0, zero_division=0))
        ensemble_metrics['f1'].append(f1_score(y_test, y_pred, zero_division=0))
        
        if len(np.unique(y_test)) > 1:
            ensemble_metrics['auc'].append(roc_auc_score(y_test, y_proba))
    
    # Calculate mean performance
    ensemble_performance = {metric: np.mean(values) for metric, values in ensemble_metrics.items()}
    
    print("\n=== Final Ensemble Performance ===")
    for metric, value in ensemble_performance.items():
        print(f"{metric.capitalize()}: {value:.3f}")
    
    # Print model comparison
    print("\n=== Model Comparison ===")
    metrics_to_compare = ['auc', 'sensitivity', 'specificity', 'f1']
    for metric in metrics_to_compare:
        print(f"\n{metric.upper()}:")
        for model_name, perf in model_performances.items():
            print(f"  {model_name}: {perf.get(metric, 0):.3f}")
        print(f"  ensemble: {ensemble_performance.get(metric, 0):.3f}")
    
    # Return ensemble and performance metrics
    return ensemble, ensemble_performance

# Main execution
if __name__ == "__main__":
    X, y, patient_ids = load_dataset_with_clinical_data("heart_sounds/", "training_data.csv")
    
    # Train and evaluate the ensemble model
    final_model, model_performance = train_model(X, y, patient_ids)
    
    # Save the model and feature names
    joblib.dump(final_model, 'heart_sound_model.joblib')
    joblib.dump(X.columns.tolist(), 'feature_names.joblib')
    
    # Print final performance metrics
    print("\n=== Final Model Performance ===")
    for metric, value in model_performance.items():
        print(f"{metric.capitalize()}: {value:.3f}")
    print("\nSaved trained heart sound ML model")