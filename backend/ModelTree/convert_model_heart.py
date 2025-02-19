import tensorflow as tf
import numpy as np
import joblib
from sklearn.tree import DecisionTreeClassifier

# Load the scikit-learn model
model = joblib.load('heart_murmur_model.joblib')

# Extract the decision tree structure
n_nodes = model.tree_.node_count
children_left = model.tree_.children_left
children_right = model.tree_.children_right
feature = model.tree_.feature
threshold = model.tree_.threshold
value = model.tree_.value

# Create a function to convert the scikit-learn model to a TensorFlow model
class SklearnDecisionTree(tf.Module):
    def __init__(self, children_left, children_right, feature, threshold, value):
        self.children_left = children_left
        self.children_right = children_right
        self.feature = feature
        self.threshold = threshold
        self.value = value

    @tf.function(input_signature=[tf.TensorSpec(shape=[None, len(feature)], dtype=tf.float32)])
    def __call__(self, x):
        def predict(inputs):
            def traverse_tree(node, sample):
                if self.children_left[node] == self.children_right[node]:  # leaf node
                    return self.value[node].argmax()
                if sample[self.feature[node]] <= self.threshold[node]:
                    return traverse_tree(self.children_left[node], sample)
                else:
                    return traverse_tree(self.children_right[node], sample)

            return tf.map_fn(lambda sample: traverse_tree(0, sample), inputs, dtype=tf.int64)

        predictions = predict(x)
        return tf.one_hot(predictions, depth=self.value.shape[2])

# Define the input shape (number of features)
input_shape = (None, len(model.feature_importances_))

# Convert the scikit-learn model to a TensorFlow model
tf_model = SklearnDecisionTree(children_left, children_right, feature, threshold, value)

# Convert the TensorFlow model to TensorFlow Lite
converter = tf.lite.TFLiteConverter.from_concrete_functions([tf_model.__call__.get_concrete_function()])
tflite_model = converter.convert()

# Save the TensorFlow Lite model
with open("heart_murmur.tflite", "wb") as f:
    f.write(tflite_model)