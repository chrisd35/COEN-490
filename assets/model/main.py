from fastapi import FastAPI, File, UploadFile, HTTPException, Depends
import firebase_admin
from firebase_admin import credentials, storage, auth
from extract_features import extract_features
import joblib
import numpy as np
import librosa
import tempfile
import os
import pandas as pd

app = FastAPI()

# Initialize Firebase
cred = credentials.Certificate("service-account.json")
firebase_admin.initialize_app(cred, {'storageBucket': 'respirhythm.firebasestorage.app/files'})

# Load trained model
model = joblib.load('random_forest_pca_model.joblib')

@app.post("/analyze")
async def analyze_heart_sound(firebase_path: str, token: str = Depends()):
    try:
        # Verify Firebase Auth token
        decoded_token = auth.verify_id_token(token)
        uid = decoded_token['uid']

        # 1. Download audio from Firebase
        bucket = storage.bucket()
        blob = bucket.blob(firebase_path)
        temp_file = tempfile.NamedTemporaryFile(delete=False)
        blob.download_to_filename(temp_file.name)
        
        # 2. Extract features
        features, _ = extract_features(temp_file.name)
        if "error" in features:
            raise HTTPException(400, detail=features["error"])
        
        # 3. Format features for model
        X = pd.DataFrame([features]).fillna(0)
        
        # 4. Make prediction
        proba = model.predict_proba(X)[0][1]
        prediction = "Abnormal" if proba > 0.5 else "Normal"
        
        # 5. Generate suggestions
        suggestions = generate_clinical_suggestions(prediction, features)
        
        return {
            "prediction": prediction,
            "confidence": float(proba),
            "suggestions": suggestions,
            "features": features
        }
    finally:
        os.unlink(temp_file.name)

def generate_clinical_suggestions(prediction, features):
    # Add domain-specific logic here
    if prediction == "Abnormal":
        return ["Consider further echocardiogram", "Potential murmur detected"]
    return ["No immediate action required"]