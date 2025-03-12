import joblib
import librosa
import numpy as np
import pandas as pd
import sys
import os
from extract_features import extract_features

# Load model and feature names
model = joblib.load('heart_murmur_model.joblib')
feature_names = joblib.load('feature_names.joblib')

def predict_single_recording(file_path):
    try:
        # Extract valve from filename (e.g., "9983_AV.wav" -> "AV")
        filename = os.path.basename(file_path)
        valve = filename.split("_")[-1].split(".")[0].upper()
        
        # Validate valve
        VALVE_PREFIXES = ["AV", "MV", "PV", "TV"]
        if valve not in VALVE_PREFIXES:
            return {"error": f"Invalid valve '{valve}' in filename. Use format: [ID]_[Valve].wav"}
        
        # Extract features
        features = extract_features(file_path, valve)
        if "error" in features:
            return {"error": features["error"]}
        
        # Rest of the code remains unchanged
        X = pd.DataFrame([features]).reindex(columns=feature_names).fillna(0)
        prediction = model.predict(X)[0]
        proba = model.predict_proba(X)[0][1]
        
        return {
            "prediction": "Abnormal" if prediction == 1 else "Normal",
            "confidence": float(proba),
            "valve": valve,  # Add valve to output
            "features_used": X.columns[X.iloc[0] != 0].tolist()
        }
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    if len(sys.argv) != 2:  # Changed from 3 to 2
        print("Usage: python predict_heart_murmur.py <path/to/audio.wav>")
        print("Filename must contain valve (e.g., 9983_AV.wav)")
        sys.exit(1)
    
    result = predict_single_recording(sys.argv[1])
    print("\n=== Prediction Result ===")
    print(f"Valve: {result.get('valve', 'Unknown')}")
    print(f"Prediction: {result.get('prediction', 'Error')}")
    print(f"Confidence: {result.get('confidence', 0):.2f}")
    print(f"Features Used: {result.get('features_used', [])}")
    if "error" in result:
        print(f"\nError: {result['error']}")