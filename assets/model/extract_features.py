import librosa
import numpy as np
import sys
import json
import os

def extract_features(file_path, valve="Unknown"):
    try:
        if not os.path.exists(file_path):
            return {"error": f"File not found: {file_path}"}
            
        y, sr = librosa.load(file_path, sr=None)
        
        # Calculate Nyquist frequency
        nyquist = sr // 2
        
        # Extract MFCCs (13 coefficients)
        mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
        mfccs_mean = np.mean(mfccs.T, axis=0)

        # Spectral Contrast with Nyquist-safe parameters
        spectral_contrast = librosa.feature.spectral_contrast(
            y=y,
            sr=sr,
            fmin=200.0,       # Default is 200Hz
            n_bands=3       # Default is 6 bands
        )
        spectral_contrast_mean = np.mean(spectral_contrast, axis=1)

        # Zero Crossing Rate
        zcr = librosa.feature.zero_crossing_rate(y)
        zcr_mean = np.mean(zcr)

        # Combine features
        features_dict = {}
        for i, value in enumerate(mfccs_mean.tolist()):
            features_dict[f"{valve}_MFCC_{i+1}"] = float(value)
        for i, value in enumerate(spectral_contrast_mean.tolist()):
            features_dict[f"{valve}_SpectralContrast_{i+1}"] = float(value)
        features_dict[f"{valve}_ZeroCrossingRate"] = float(zcr_mean)
        return features_dict
    
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    try:
        if len(sys.argv) < 3:
            print(json.dumps({"error": "Usage: python extract_features.py <file.wav> <Valve>"}))
            sys.exit(1)
            
        file_path = sys.argv[1]
        valve = sys.argv[2]
        features = extract_features(file_path, valve)
        
        if isinstance(features, dict):
            if "error" in features:
                print(f"Error: {features['error']}")
            else:
                print("\nExtracted Features:")
                print("-" * 50)
                # Print in order: MFCCs, Spectral Contrast, ZCR
                for feature in sorted(features.keys()):
                    value = features[feature]
                    print(f"{feature:20}: {value:.6f}")
                print("-" * 50)
                print("\nJSON output:")
                print(json.dumps(features))
            
    except Exception as e:
        print(json.dumps({"error": str(e)}))