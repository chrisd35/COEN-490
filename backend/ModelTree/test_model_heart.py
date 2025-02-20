import numpy as np
import tensorflow as tf

# Load the TensorFlow Lite model
interpreter = tf.lite.Interpreter(model_path="heart_murmur.tflite")
interpreter.allocate_tensors()

# Get input and output tensors
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# Print input and output details
print("Input details:", input_details)
print("Output details:", output_details)

# Create a sample input data (replace with actual data)
# Ensure the input data shape matches the model's input shape
sample_input = np.random.rand(1, input_details[0]['shape'][1]).astype(np.float32)

# Set the tensor to point to the input data to be inferred
interpreter.set_tensor(input_details[0]['index'], sample_input)

# Run the inference
interpreter.invoke()

# Get the output tensor
output_data = interpreter.get_tensor(output_details[0]['index'])
print("Output data:", output_data)