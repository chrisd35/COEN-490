import librosa
import numpy as np
import sys
import json

def extract_features(file_path):
    y, sr = librosa.load(file_path, sr=None)
    mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    mfccs = np.mean(mfccs.T, axis=0)
    return mfccs.tolist()

if __name__ == "__main__":
    file_path = sys.argv[1]
    features = extract_features(file_path)
    print(json.dumps(features))