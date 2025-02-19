import librosa
import numpy as np
import sys
import json
import os

def extract_features(file_path):
    try:
        # Ensure file exists
        if not os.path.exists(file_path):
            return {"error": f"File not found: {file_path}"}
            
        # Load audio file
        y, sr = librosa.load(file_path, sr=None)
        
        # Extract MFCCs
        mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
        mfccs = np.mean(mfccs.T, axis=0)
        return mfccs.tolist()
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    try:
        if len(sys.argv) < 2:
            print(json.dumps({"error": "No file path provided"}))
            sys.exit(1)
            
        file_path = sys.argv[1]
        features = extract_features(file_path)
        
        # Handle error result
        if isinstance(features, dict) and "error" in features:
            print(json.dumps(features))
        else:
            print(json.dumps(features))
            
    except Exception as e:
        print(json.dumps({"error": str(e)}))