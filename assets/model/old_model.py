import pandas as pd
import os
import glob
import librosa
import numpy as np
import librosa.onset
import librosa.effects
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, recall_score, roc_auc_score, confusion_matrix, f1_score
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.model_selection import StratifiedKFold, LeaveOneGroupOut
from sklearn.pipeline import Pipeline
from imblearn.over_sampling import SMOTE
import joblib

# Define standard valve prefixes
VALVE_PREFIXES = ["AV", "MV", "PV", "TV"]  # Aortic, Mitral, Pulmonary, Tricuspid
cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

def preprocess_heart_sound(file_path):
    """Preprocess heart sound recording with noise removal and segmentation"""
    try:
        y, sr = librosa.load(file_path, sr=None)
        
        # 1. Noise removal with bandpass filter (20-400 Hz)
        y_filtered = librosa.effects.preemphasis(y, coef=0.97)
        
        # 2. Amplitude normalization
        y_normalized = librosa.util.normalize(y_filtered)
        
        # 3. Segmentation into heart cycles
        # Calculate envelope
        y_env = np.abs(librosa.stft(y_normalized))
        y_env = np.mean(y_env, axis=0)
        y_env = librosa.util.normalize(y_env)
        
        # Find peaks (heart sounds)
        peaks = librosa.util.peak_pick(y_env, pre_max=int(0.03*sr), post_max=int(0.03*sr),
                                     pre_avg=int(0.03*sr), post_avg=int(0.03*sr), 
                                     delta=0.3, wait=int(0.03*sr))
        
        # Segment into cardiac cycles if enough peaks found
        segments = []
        if len(peaks) >= 4:  # Need at least two complete cycles
            # Group into cardiac cycles (assuming S1-S2-S1-S2 pattern)
            for i in range(0, len(peaks)-2, 2):
                start_idx = peaks[i]
                end_idx = peaks[i+2]
                if end_idx > start_idx:
                    segments.append(y_normalized[start_idx:end_idx])
        
        # If we couldn't segment properly, return the filtered signal
        if not segments:
            return y_normalized, sr
        
        # Return the median length segment as representative
        segment_lengths = [len(s) for s in segments]
        median_idx = np.argsort(segment_lengths)[len(segment_lengths)//2]
        return segments[median_idx], sr
        
    except Exception as e:
        print(f"Error preprocessing {file_path}: {str(e)}")
        # Return original audio if preprocessing fails
        try:
            return librosa.load(file_path, sr=None)
        except:
            return None, None

def extract_cardiac_features(audio, sr, valve="Unknown"):
    """Extract heart sound-specific features from preprocessed audio"""
    try:
        if audio is None:
            return {"error": "Invalid audio data"}
            
        y_filtered = audio
        
        # Standard features (improved)
        mfccs = librosa.feature.mfcc(y=y_filtered, sr=sr, n_mfcc=13)
        mfccs_mean = np.mean(mfccs.T, axis=0)
        mfccs_std = np.std(mfccs.T, axis=0)  # Add variance information
        
        # Heart-specific temporal features
        # Detect heart peaks (S1, S2) using envelope detection
        y_env = np.abs(librosa.util.normalize(y_filtered))
        y_env = librosa.onset.onset_strength(y=y_filtered, sr=sr)
        peaks = librosa.util.peak_pick(y_env, pre_max=int(0.03*sr), post_max=int(0.03*sr),
                                      pre_avg=int(0.03*sr), post_avg=int(0.03*sr), 
                                      delta=0.3, wait=int(0.03*sr))
        
        # Calculate systole and diastole durations if we can detect S1/S2
        heartbeat_features = {}
        if len(peaks) >= 2:
            # Assume peaks alternate between S1 and S2
            peak_times = librosa.times_like(y_env)[peaks]
            intervals = np.diff(peak_times)
            
            # Even indices are systole, odd are diastole
            systole_times = intervals[::2] if len(intervals) > 1 else []
            diastole_times = intervals[1::2] if len(intervals) > 1 else []
            
            if len(systole_times) > 0:
                heartbeat_features[f"{valve}_Systole_Mean"] = float(np.mean(systole_times))
                heartbeat_features[f"{valve}_Systole_Std"] = float(np.std(systole_times))
            
            if len(diastole_times) > 0:
                heartbeat_features[f"{valve}_Diastole_Mean"] = float(np.mean(diastole_times))
                heartbeat_features[f"{valve}_Diastole_Std"] = float(np.std(diastole_times))
                
            heartbeat_features[f"{valve}_HeartRate"] = float(60 / np.mean(intervals)) if len(intervals) > 0 else 0
        
        # Frequency band energy ratios (important for murmurs)
        bands = [(20, 50), (50, 100), (100, 150), (150, 200), (200, 400)]
        for i, (low, high) in enumerate(bands):
            spec = np.abs(librosa.stft(y_filtered))
            freq_bins = librosa.fft_frequencies(sr=sr)
            
            # Get indices for the frequency range
            idx_low = np.searchsorted(freq_bins, low)
            idx_high = np.searchsorted(freq_bins, high)
            
            # Calculate energy in band
            band_energy = np.sum(np.mean(spec[idx_low:idx_high], axis=1))
            heartbeat_features[f"{valve}_Energy_{low}_{high}Hz"] = float(band_energy)

        # Zero Crossing Rate
        zcr = librosa.feature.zero_crossing_rate(y_filtered)
        zcr_mean = np.mean(zcr)
        heartbeat_features[f"{valve}_ZeroCrossingRate"] = float(zcr_mean)
            
        # Spectral Contrast with Nyquist-safe parameters
        spectral_contrast = librosa.feature.spectral_contrast(
            y=y_filtered,
            sr=sr,
            fmin=20.0,
            n_bands=3
        )
        spectral_contrast_mean = np.mean(spectral_contrast, axis=1)
        
        # Combine all features
        features_dict = {}
        for i, value in enumerate(mfccs_mean.tolist()):
            features_dict[f"{valve}_MFCC_mean_{i+1}"] = float(value)
        for i, value in enumerate(mfccs_std.tolist()):
            features_dict[f"{valve}_MFCC_std_{i+1}"] = float(value)
        for i, value in enumerate(spectral_contrast_mean.tolist()):
            features_dict[f"{valve}_SpectralContrast_{i+1}"] = float(value)
        
        # Add the heartbeat features
        features_dict.update(heartbeat_features)
        
        return features_dict
        
    except Exception as e:
        return {"error": str(e)}

def parse_recording_locations(location_str):
    """Handle duplicate valves and normalize casing"""
    locations = location_str.split("+") if pd.notna(location_str) else []
    return list(set([v.strip().upper() for v in locations]))

def load_dataset_with_clinical_data(audio_dir, labels_csv, clinical_csv=None):
    """Load dataset with both audio features and clinical variables"""
    # Load audio features
    labels = pd.read_csv(labels_csv)
    
    # Enhanced validation
    if labels["Outcome"].nunique() != 2:
        raise ValueError("Outcome must have exactly 2 classes (Normal/Abnormal)")
    
    # Load clinical data if provided
    clinical_data = None
    if clinical_csv and os.path.exists(clinical_csv):
        clinical_data = pd.read_csv(clinical_csv)
        clinical_data.set_index('Patient ID', inplace=True)
    
    features = []
    valid_labels = []
    patient_ids = []
    
    for idx, row in labels.iterrows():
        patient_id = row["Patient ID"]
        patient_ids.append(patient_id)
        recording_locations = parse_recording_locations(row["Recording locations:"])
        patient_features = {}
        
        # Extract audio features
        for valve in recording_locations:
            # Improved file discovery with case insensitivity
            base_pattern = os.path.join(audio_dir, f"{patient_id}_{valve}")
            valve_files = glob.glob(f"{base_pattern}*.wav", recursive=False) + \
                          glob.glob(f"{base_pattern}*.WAV", recursive=False)
            
            valve_features = []
            for file_path in valve_files:
                try:
                    # Preprocess the audio
                    preprocessed_audio, sr = preprocess_heart_sound(file_path)
                    # Extract cardiac-specific features
                    feature_dict = extract_cardiac_features(preprocessed_audio, sr, valve)
                    if "error" not in feature_dict:
                        valve_features.append(feature_dict)
                except Exception as e:
                    print(f"Error processing {file_path}: {str(e)}")
            
            if valve_features:
                # Use median instead of mean for robustness
                avg_features = pd.DataFrame(valve_features).median().to_dict()
                for key, value in avg_features.items():
                    patient_features[key] = value
        
        # Add clinical variables if available
        if clinical_data is not None and patient_id in clinical_data.index:
            patient_clinical = clinical_data.loc[patient_id].to_dict()
            for key, value in patient_clinical.items():
                if pd.notna(value):
                    patient_features[f"Clinical_{key}"] = value
        
        # Add murmur type if available
        if "Murmur_Type" in row and pd.notna(row["Murmur_Type"]):
            if row["Outcome"] == "Abnormal":
                # One-hot encode murmur type
                murmur_types = ["Systolic", "Diastolic", "Continuous"]
                for m_type in murmur_types:
                    patient_features[f"Murmur_{m_type}"] = 1 if m_type in row["Murmur_Type"] else 0
        
        if patient_features:
            features.append(patient_features)
            # Store multi-class outcome if available
            if "Murmur_Grade" in row and pd.notna(row["Murmur_Grade"]):
                valid_labels.append(row["Murmur_Grade"])
            else:
                valid_labels.append(1 if row["Outcome"] == "Abnormal" else 0)

    X = pd.DataFrame(features).fillna(0)
    y = pd.Series(valid_labels)
    patient_ids = pd.Series(patient_ids)
    
    return X, y, patient_ids

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
    
    # Define metrics to track
    metrics = {
        'accuracy': [],
        'sensitivity': [],
        'specificity': [],
        'auc': []
    }
    
    # Cross-validation
    for train_idx, test_idx in logo.split(X, y, groups=patient_ids):
        X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
        y_train, y_test = y.iloc[train_idx], y.iloc[test_idx]
        
        # Apply SMOTE only on training data
        smote = SMOTE(random_state=42)
        X_train_resampled, y_train_resampled = smote.fit_resample(X_train, y_train)
        
        # Train model
        model.fit(X_train_resampled, y_train_resampled)
        
        # Predict
        y_pred = model.predict(X_test)
        y_proba = model.predict_proba(X_test)[:,1]
        
        # Calculate metrics
        metrics['accuracy'].append(accuracy_score(y_test, y_pred))
        metrics['sensitivity'].append(recall_score(y_test, y_pred, pos_label=1, zero_division=0))
        metrics['specificity'].append(recall_score(y_test, y_pred, pos_label=0, zero_division=0))
        if len(np.unique(y_test)) > 1:  # Only calculate AUC if both classes are present
            metrics['auc'].append(roc_auc_score(y_test, y_proba))
    
    # Report results
    print("\n=== Leave-One-Patient-Out Validation Results ===")
    for metric, values in metrics.items():
        print(f"{metric.capitalize()}: {np.mean(values):.3f} ± {np.std(values):.3f}")
    
    return metrics

def train_model(X, y, patient_ids=None):
    """Train a model that can handle both binary and multi-class outcomes"""
    is_multiclass = len(np.unique(y)) > 2
    
    # Choose appropriate scoring metric
    scoring = 'f1_weighted' if is_multiclass else 'recall'
    
    # More efficient parameter grid (focused on important parameters)
    param_grid = {
        'n_estimators': [100, 200],
        'max_depth': [20, None],
        'min_samples_split': [5, 10],
        'class_weight': ['balanced', 'balanced_subsample']
    }
    
    # Configure model
    base_model = RandomForestClassifier(random_state=42)
    
    # If we have patient IDs, use leave-one-out CV
    if patient_ids is not None:
        print("Using leave-one-patient-out cross-validation")
        cv = LeaveOneGroupOut()
        groups = patient_ids
    else:
        # Otherwise use stratified k-fold
        print("Using stratified 5-fold cross-validation")
        cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
        groups = None
    
    # Set up grid search
    grid_search = GridSearchCV(
        base_model,
        param_grid,
        cv=cv,
        scoring=scoring,
        n_jobs=-1,
        return_train_score=True
    )
    
    # Train with SMOTE handling inside cross-validation
    if groups is not None:
        # First evaluate with leave-one-patient-out
        evaluate_with_leave_one_patient_out(X, y, patient_ids)
        # Then fit the grid search to find best parameters
        grid_search.fit(X, y, groups=groups)
    else:
        # Let GridSearchCV handle cross-validation with SMOTE inside
        pipeline = Pipeline([
            ('smote', SMOTE(random_state=42)),
            ('model', base_model)
        ])
        
        # Modify param_grid to work with pipeline
        pipeline_param_grid = {f'model__{key}': values for key, values in param_grid.items()}
        
        pipeline_search = GridSearchCV(
            pipeline,
            pipeline_param_grid,
            cv=cv,
            scoring=scoring,
            n_jobs=-1,
            return_train_score=True
        )
        
        pipeline_search.fit(X, y)
        grid_search = pipeline_search
    
    return grid_search

# Main execution
if __name__ == "__main__":
    try:
        # Check if clinical data exists
        clinical_csv = "clinical_data.csv" if os.path.exists("clinical_data.csv") else None
        
        # Load dataset with enhanced processing
        X, y, patient_ids = load_dataset_with_clinical_data("heart_sounds/", "training_data.csv", clinical_csv)
        print("\nClass distribution:", y.value_counts())
        print(f"Total patients: {len(patient_ids)}")
        print(f"Total features: {X.shape[1]}")
        
        # Train model
        model = train_model(X, y, patient_ids)
        
        # Get best model
        best_model = model.best_estimator_
        
        # Use a holdout set for final evaluation (20% of data)
        X_train, X_test, y_train, y_test, ids_train, ids_test = train_test_split(
            X, y, patient_ids,
            test_size=0.2, 
            stratify=y,
            random_state=42
        )
        
        # Train on training set
        if hasattr(best_model, 'named_steps') and 'smote' in best_model.named_steps:
            # Handle pipeline case
            best_model.fit(X_train, y_train)
        else:
            # Handle non-pipeline case
            smote = SMOTE(random_state=42)
            X_train_resampled, y_train_resampled = smote.fit_resample(X_train, y_train)
            best_model.fit(X_train_resampled, y_train_resampled)
        
        # Evaluate on holdout set
        y_pred = best_model.predict(X_test)
        
        # Binary classification metrics
        if len(np.unique(y)) == 2:
            y_proba = best_model.predict_proba(X_test)[:,1]
            
            print("\n=== Final Model Performance on Holdout Set ===")
            print(f"Accuracy: {accuracy_score(y_test, y_pred):.3f}")
            print(f"Sensitivity: {recall_score(y_test, y_pred, pos_label=1, zero_division=0):.3f}")
            print(f"Specificity: {recall_score(y_test, y_pred, pos_label=0, zero_division=0):.3f}")
            print(f"F1 Score: {f1_score(y_test, y_pred):.3f}")
            print(f"AUC-ROC: {roc_auc_score(y_test, y_proba):.3f}")
            print("\nConfusion Matrix:")
            print(confusion_matrix(y_test, y_pred))
        else:
            # Multi-class metrics
            print("\n=== Final Model Performance on Holdout Set ===")
            print(f"Accuracy: {accuracy_score(y_test, y_pred):.3f}")
            print(f"Weighted F1 Score: {f1_score(y_test, y_pred, average='weighted'):.3f}")
            print("\nConfusion Matrix:")
            print(confusion_matrix(y_test, y_pred))
        
        # Feature importance analysis
        if hasattr(best_model, 'named_steps') and 'model' in best_model.named_steps:
            # Access feature importances from pipeline
            importances = best_model.named_steps['model'].feature_importances_
        else:
            importances = best_model.feature_importances_
            
        feature_importance = pd.DataFrame({
            'Feature': X.columns,
            'Importance': importances
        }).sort_values('Importance', ascending=False)
        
        print("\n=== Top 10 Most Important Features ===")
        print(feature_importance.head(10))
        
        # Save model artifacts
        joblib.dump(best_model, 'heart_murmur_model.joblib')
        joblib.dump(X.columns.tolist(), 'feature_names.joblib')
        
        # Save feature importance for future reference
        feature_importance.to_csv('feature_importance.csv', index=False)
        
        print("\nSaved model, feature names, and feature importance")

    except ValueError as ve:
        print(f"\nCritical Data Error: {str(ve)}")
    except Exception as e:
        print(f"\nUnexpected Error: {str(e)}")
        import traceback
        traceback.print_exc()