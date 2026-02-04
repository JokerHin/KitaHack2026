from flask import Flask, request, jsonify
import joblib
import numpy as np
import tensorflow as tf
import os

MODEL_PATH = "triage_model.keras"
SCALER_PATH = "scaler.pkl"

app = Flask(__name__)

# Load model and scaler
print("Loading model and scaler...")
if not os.path.exists(MODEL_PATH) or not os.path.exists(SCALER_PATH):
    raise RuntimeError("Model or scaler not found. Run main.py train to create them.")

model = tf.keras.models.load_model(MODEL_PATH)
scaler = joblib.load(SCALER_PATH)
print("Model and scaler loaded.")

@app.route('/predict', methods=['POST'])
def predict():
    data = request.get_json(force=True)
    features = data.get('features') or {}
    # Expected keys: age, heart_rate, oxygen, temperature, pain_scale, waiting_time, complaint_encoded
    order = ['age','heart_rate','oxygen','temperature','pain_scale','waiting_time','complaint_encoded']
    x = [float(features.get(k, 0.0)) for k in order]
    X = np.array([x])
    try:
        Xs = scaler.transform(X)
    except Exception as e:
        # fallback: try to reshape
        Xs = X
    prob = float(model.predict(Xs, verbose=0).ravel()[0])
    return jsonify({'probability': prob})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
