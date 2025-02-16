import pandas as pd
from sklearn.tree import DecisionTreeClassifier, export_text
from sklearn.model_selection import train_test_split, cross_val_score, KFold, GridSearchCV
import joblib
import numpy as np

# Load CSV data
data = pd.read_csv('training_data.csv')

# Convert categorical columns to numerical using one-hot encoding
data = pd.get_dummies(data, columns=['Recording locations:', 'Age', 'Sex', 'Pregnancy status', 'Murmur', 'Murmur locations', 'Most audible location', 'Systolic murmur timing', 'Systolic murmur shape', 'Systolic murmur grading', 'Systolic murmur pitch', 'Systolic murmur quality', 'Diastolic murmur timing', 'Diastolic murmur shape', 'Diastolic murmur grading', 'Diastolic murmur pitch', 'Diastolic murmur quality', 'Campaign'])

# Drop the Outcome before splitting
X = data.drop('Outcome', axis=1)
y = data['Outcome']

# Add hyperparameter tuning
param_grid = {
    'max_depth': [3, 5, 7, 10],
    'min_samples_split': [2, 5, 10],
    'min_samples_leaf': [1, 2, 4]
}

grid_search = GridSearchCV(
    DecisionTreeClassifier(random_state=5),
    param_grid,
    cv=5,
    scoring='accuracy'
)
grid_search.fit(X, y)
model = grid_search.best_estimator_

# Add cross-validation
k_folds = 5
kf = KFold(n_splits=k_folds, shuffle=True, random_state=5)
cv_scores = cross_val_score(model, X, y, cv=kf, scoring='accuracy')

# Print cross-validation results
print(f"\nCross-validation scores: {cv_scores}")
print(f"Average CV Score: {cv_scores.mean():.2f} (+/- {cv_scores.std() * 2:.2f})")

# Train final model on full dataset
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=5)
model.fit(X_train, y_train)

# Add model evaluation
accuracy = model.score(X_test, y_test)
print(f"Model Accuracy: {accuracy:.2f}")

# Save the trained model
joblib.dump(model, 'heart_murmur_model.joblib')

# Verify feature names (critical for Flutter implementation)
print("Model Features:", X.columns.tolist())