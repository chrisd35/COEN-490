import pandas as pd
from sklearn.tree import DecisionTreeClassifier, export_text
from sklearn.model_selection import train_test_split
import joblib

# Load CSV data
data = pd.read_csv('training_data.csv')

# Convert categorical columns to numerical using one-hot encoding
data = pd.get_dummies(data, columns=['Recording locations:', 'Age', 'Sex', 'Pregnancy status', 'Murmur', 'Murmur locations', 'Most audible location', 'Systolic murmur timing', 'Systolic murmur shape', 'Systolic murmur grading', 'Systolic murmur pitch', 'Systolic murmur quality', 'Diastolic murmur timing', 'Diastolic murmur shape', 'Diastolic murmur grading', 'Diastolic murmur pitch', 'Diastolic murmur quality', 'Campaign'])

# Drop the Outcome before splitting
X = data.drop('Outcome', axis=1)
y = data['Outcome']

# Train model
model = DecisionTreeClassifier(random_state=5)
# model.fit(X, y)

# Replace current training code with:
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=5)
model.fit(X_train, y_train)

# Add model evaluation
accuracy = model.score(X_test, y_test)
print(f"Model Accuracy: {accuracy:.2f}")

# Save the trained model
joblib.dump(model, 'heart_murmur_model.joblib')

# Verify feature names (critical for Flutter implementation)
print("Model Features:", X.columns.tolist())