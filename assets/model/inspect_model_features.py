import joblib

# Load the feature names saved during training
try:
    feature_names = joblib.load('feature_names.joblib')
    spectral_contrast_features = [f for f in feature_names if "SpectralContrast" in f]
    
    print("=== Spectral Contrast Features ===")
    print(spectral_contrast_features)
    
    num_bands = len(set([f.split('_')[-1] for f in spectral_contrast_features]))
    print(f"\nNumber of Spectral Contrast Bands: {num_bands}")

except FileNotFoundError:
    print("Error: feature_names.joblib not found. Train the model first.")
except Exception as e:
    print(f"Error: {str(e)}")