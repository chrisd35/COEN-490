from fastapi import FastAPI, File, UploadFile, HTTPException, Depends
from fastapi import Body
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
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

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development only - tighten for production
    allow_credentials=True,
    allow_methods=["POST", "GET"],
    allow_headers=["Authorization", "Content-Type"],
)

# Initialize Firebase
cred = credentials.Certificate("service-account.json")
firebase_admin.initialize_app(cred, {'storageBucket': 'respirhythm.firebasestorage.app'})

# Load trained model
model = joblib.load('heart_sound_model.joblib')

@app.post("/analyze")
async def analyze_heart_sound(firebase_path: str = Body(..., embed=True), token: str = Depends(oauth2_scheme)):
    try:
        # Verify Firebase Auth token
        decoded_token = auth.verify_id_token(token)
        uid = decoded_token['uid']

        # Validate file path format
        if not firebase_path.startswith('users/'):
            raise HTTPException(400, "Invalid file path format")

        # 1. Download audio from Firebase
        bucket = storage.bucket()
        blob = bucket.blob(firebase_path)
        temp_file = tempfile.NamedTemporaryFile(delete=False)
        blob.download_to_filename(temp_file.name)
        temp_file.close()  # Explicitly close the file
        
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