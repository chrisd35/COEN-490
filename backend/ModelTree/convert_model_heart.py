# convert_model.py
import tensorflow as tf
import numpy as np
import joblib
from sklearn.tree import DecisionTreeClassifier

# Load the scikit-learn model
model = joblib.load('heart_murmur_model.joblib')

# Create a function to convert the scikit-learn model to a TensorFlow model
def sklearn_to_tf(model, input_shape):
    class SklearnModel(tf.Module):
        def __init__(self, model):
            self.model = model

        @tf.function(input_signature=[tf.TensorSpec(shape=input_shape, dtype=tf.float32)])
        def __call__(self, x):
            return tf.convert_to_tensor(self.model.predict(x.numpy()), dtype=tf.float32)

    return SklearnModel(model)

# Define the input shape (number of features)
input_shape = (None, len(model.feature_importances_))

# Convert the scikit-learn model to a TensorFlow model
tf_model = sklearn_to_tf(model, input_shape)

# Convert the TensorFlow model to TensorFlow Lite
converter = tf.lite.TFLiteConverter.from_concrete_functions([tf_model.__call__.get_concrete_function()])
tflite_model = converter.convert()

# Save the TensorFlow Lite model
with open("heart_murmur.tflite", "wb") as f:
    f.write(tflite_model)