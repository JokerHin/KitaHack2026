"""Simple retraining script stub.

Reads `feedback_log.jsonl`, trains a binary classifier, saves a Keras model and a TFLite file.
This is a starting point — extend with proper preprocessing, validation, and hyperparameter tuning.
"""
import json
from pathlib import Path
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import tensorflow as tf

ROOT = Path(__file__).resolve().parents[1]
LOG_PATH = ROOT / "feedback_log.jsonl"

def load_feedback(path):
    if not path.exists():
        raise FileNotFoundError(path)
    rows = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            rows.append(json.loads(line))
    return rows

def build_dataset(rows):
    # Placeholder — adapt to your logged schema
    records = [r["patient_data"] for r in rows]
    df = pd.DataFrame(records)
    # Expect `label` to be present in original dataset or feedback
    if "label" not in df.columns:
        raise RuntimeError("No label column in feedback logs — include clinician decisions")
    X = df.drop("label", axis=1)
    y = df["label"]
    return X, y

def train():
    rows = load_feedback(LOG_PATH)
    X, y = build_dataset(rows)
    scaler = StandardScaler()
    Xs = scaler.fit_transform(X)

    X_train, X_val, y_train, y_val = train_test_split(Xs, y, test_size=0.2, random_state=42)

    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(X_train.shape[1],)),
        tf.keras.layers.Dense(16, activation="relu"),
        tf.keras.layers.Dense(8, activation="relu"),
        tf.keras.layers.Dense(1, activation="sigmoid")
    ])

    model.compile(optimizer="adam", loss="binary_crossentropy", metrics=["accuracy"])

    model.fit(X_train, y_train, epochs=20, batch_size=32, validation_data=(X_val, y_val))

    model.save(ROOT / "retrained_model.keras")

    # Export to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    (ROOT / "model.tflite").write_bytes(tflite_model)

    # Save scaler
    import joblib
    joblib.dump(scaler, ROOT / "scaler_retrained.pkl")

    print("Retraining complete: retrained_model.keras, model.tflite, scaler_retrained.pkl")

if __name__ == "__main__":
    train()
