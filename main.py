import os
import json
import joblib
import numpy as np
import pandas as pd
import tensorflow as tf
from datetime import datetime
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, roc_auc_score, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight

from google import genai

# =========================
# Configuration
# =========================

MODEL_VERSION = "v2.0"
MODEL_PATH = "triage_model.keras"
TFLITE_MODEL_PATH = "mobile/flutter/assets/model.tflite"
SCALER_PATH = "scaler.pkl"
DATASET_PATH = "triage_synthetic_dataset.csv"
FEEDBACK_LOG_PATH = "feedback_log.jsonl"

# =========================
# Google AI Studio Setup
# =========================

_GOOGLE_API_KEY = os.environ.get("GOOGLE_API_KEY")
if _GOOGLE_API_KEY:
    client = genai.Client(api_key=_GOOGLE_API_KEY)
else:
    client = None
    print("⚠️  Warning: GOOGLE_API_KEY not set — Gemini explanations will be disabled.")

GEMINI_MODEL = "gemini-2.5-flash"

# =========================
# Feature Engineering & Data Processing
# =========================

FEATURES = [
    "age",
    "heart_rate",
    "oxygen",
    "temperature",
    "pain_scale",
    "waiting_time",
    "complaint_encoded"
]

def load_and_prepare_data(include_feedback=True):
    """Load dataset and optionally merge with feedback logs for retraining"""
    # Load main dataset
    df = pd.read_csv(DATASET_PATH)
    
    # Optionally load feedback data for continuous learning
    if include_feedback and os.path.exists(FEEDBACK_LOG_PATH):
        feedback_records = []
        with open(FEEDBACK_LOG_PATH, 'r') as f:
            for line in f:
                record = json.loads(line)
                patient = record['patient_data']
                # Use clinician decision if available, else AI decision
                label = 1 if record.get('clinician_decision') in ['CRITICAL', 'HIGH RISK'] else 0
                patient['label'] = label
                feedback_records.append(patient)
        
        if feedback_records:
            feedback_df = pd.DataFrame(feedback_records)
            print(f"📊 Loaded {len(feedback_df)} feedback records for retraining")
            df = pd.concat([df, feedback_df], ignore_index=True)
    
    return df

def create_balanced_dataset(df):
    """Balance dataset to prevent model bias toward majority class"""
    class_counts = df['label'].value_counts()
    print(f"Original distribution: {dict(class_counts)}")
    
    # Upsample minority class
    df_majority = df[df['label'] == class_counts.idxmax()]
    df_minority = df[df['label'] == class_counts.idxmin()]
    
    from sklearn.utils import resample
    df_minority_upsampled = resample(
        df_minority,
        replace=True,
        n_samples=len(df_majority),
        random_state=42
    )
    
    df_balanced = pd.concat([df_majority, df_minority_upsampled])
    print(f"Balanced distribution: {dict(df_balanced['label'].value_counts())}")
    
    return df_balanced.sample(frac=1, random_state=42).reset_index(drop=True)

# =========================
# Enhanced Model Architecture
# =========================

def build_enhanced_model(input_dim):
    """Build improved neural network with dropout and batch normalization"""
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(input_dim,)),
        
        # First hidden layer with batch normalization
        tf.keras.layers.Dense(128, activation='relu', 
                             kernel_regularizer=tf.keras.regularizers.l2(0.001)),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.3),
        
        # Second hidden layer
        tf.keras.layers.Dense(64, activation='relu',
                             kernel_regularizer=tf.keras.regularizers.l2(0.001)),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.2),
        
        # Third hidden layer
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        
        # Output layer
        tf.keras.layers.Dense(1, activation='sigmoid')
    ])
    
    # Use Adam optimizer with learning rate scheduling
    optimizer = tf.keras.optimizers.Adam(learning_rate=0.001)
    
    model.compile(
        optimizer=optimizer,
        loss='binary_crossentropy',
        metrics=[
            'accuracy',
            tf.keras.metrics.AUC(name='auc'),
            tf.keras.metrics.Precision(name='precision'),
            tf.keras.metrics.Recall(name='recall')
        ]
    )
    
    return model

# =========================
# Training Pipeline
# =========================

def train_model(retrain=False):
    """Train or retrain the triage risk prediction model"""
    print(f"\n{'='*60}")
    print(f"🚀 Training Triage AI Model {MODEL_VERSION}")
    print(f"{'='*60}\n")
    
    # Load data
    df = load_and_prepare_data(include_feedback=retrain)
    
    # Balance dataset
    df = create_balanced_dataset(df)
    
    # Prepare features and labels
    X = df[FEATURES].values
    y = df['label'].values
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    # Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # Compute class weights for imbalanced data handling
    class_weights = compute_class_weight(
        'balanced',
        classes=np.unique(y_train),
        y=y_train
    )
    class_weight_dict = {i: weight for i, weight in enumerate(class_weights)}
    print(f"Class weights: {class_weight_dict}\n")
    
    # Build model
    model = build_enhanced_model(input_dim=X_train_scaled.shape[1])
    
    print("Model Architecture:")
    model.summary()
    print()
    
    # Callbacks
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=15,
            restore_best_weights=True,
            verbose=1
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=5,
            min_lr=1e-6,
            verbose=1
        ),
        tf.keras.callbacks.ModelCheckpoint(
            MODEL_PATH,
            monitor='val_auc',
            save_best_only=True,
            mode='max',
            verbose=1
        )
    ]
    
    # Train
    print("🎯 Training model...\n")
    history = model.fit(
        X_train_scaled, y_train,
        validation_split=0.2,
        epochs=100,
        batch_size=32,
        class_weight=class_weight_dict,
        callbacks=callbacks,
        verbose=1
    )
    
    # Evaluate
    print(f"\n{'='*60}")
    print("📊 Model Evaluation")
    print(f"{'='*60}\n")
    
    y_pred_prob = model.predict(X_test_scaled, verbose=0)
    y_pred = (y_pred_prob > 0.5).astype(int)
    
    print("Classification Report:")
    print(classification_report(y_test, y_pred, 
                                target_names=['Low Risk', 'High Risk']))
    
    print(f"\nROC-AUC Score: {roc_auc_score(y_test, y_pred_prob):.4f}")
    
    print("\nConfusion Matrix:")
    print(confusion_matrix(y_test, y_pred))
    
    # Save model and scaler
    model.save(MODEL_PATH)
    joblib.dump(scaler, SCALER_PATH)
    print(f"\n✅ Model saved to {MODEL_PATH}")
    print(f"✅ Scaler saved to {SCALER_PATH}")
    
    # Export to TFLite
    export_to_tflite(model)
    
    return model, scaler, history

def export_to_tflite(model):
    """Convert Keras model to TFLite for mobile deployment"""
    print(f"\n{'='*60}")
    print("📱 Exporting to TensorFlow Lite")
    print(f"{'='*60}\n")
    
    # Create converter
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Optimizations for mobile
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float32]
    
    # Convert
    tflite_model = converter.convert()
    
    # Save
    os.makedirs(os.path.dirname(TFLITE_MODEL_PATH), exist_ok=True)
    with open(TFLITE_MODEL_PATH, 'wb') as f:
        f.write(tflite_model)
    
    file_size = os.path.getsize(TFLITE_MODEL_PATH) / 1024
    print(f"✅ TFLite model exported to {TFLITE_MODEL_PATH}")
    print(f"📏 Model size: {file_size:.2f} KB")
    
    return TFLITE_MODEL_PATH

# =========================
# Inference Pipeline (Load Trained Model)
# =========================

def load_model_for_inference():
    """Load trained model and scaler for predictions"""
    if not os.path.exists(MODEL_PATH) or not os.path.exists(SCALER_PATH):
        print("⚠️  Model not found. Training new model...")
        model, scaler, _ = train_model()
        return model, scaler
    
    model = tf.keras.models.load_model(MODEL_PATH)
    scaler = joblib.load(SCALER_PATH)
    return model, scaler

# Initialize model and scaler
model, scaler = load_model_for_inference()

# =========================
# Risk Classification Logic
# =========================

CRITICAL_THRESHOLD = 0.8
MODERATE_THRESHOLD = 0.4

def risk_level(prob):
    """Classify risk based on probability thresholds"""
    if prob >= CRITICAL_THRESHOLD:
        return "HIGH RISK - Immediate attention"
    elif prob >= MODERATE_THRESHOLD:
        return "MODERATE RISK - Monitor closely"
    else:
        return "LOW RISK - Routine"

# =========================
# Enhanced Rule-Based Clinical Signals
# =========================

def extract_signals(data):
    """Extract clinically significant signals from patient data"""
    signals = []
    critical_count = 0

    # Oxygen saturation (SpO2)
    if data["oxygen"] < 85:
        signals.append("⚠️  CRITICAL: Severe hypoxemia (SpO2 < 85%)")
        critical_count += 1
    elif data["oxygen"] < 90:
        signals.append("⚠️  Low oxygen saturation (SpO2 < 90%)")
    elif data["oxygen"] < 93:
        signals.append("Borderline oxygen level (SpO2 < 93%)")

    # Heart rate (tachycardia/bradycardia)
    if data["heart_rate"] > 140:
        signals.append("⚠️  CRITICAL: Severe tachycardia (HR > 140)")
        critical_count += 1
    elif data["heart_rate"] > 120:
        signals.append("⚠️  Elevated heart rate (HR > 120)")
    elif data["heart_rate"] < 50:
        signals.append("⚠️  Bradycardia detected (HR < 50)")
    
    # Temperature (fever/hypothermia)
    if data["temperature"] >= 39.5:
        signals.append("⚠️  CRITICAL: High fever (≥ 39.5°C)")
        critical_count += 1
    elif data["temperature"] >= 38.5:
        signals.append("⚠️  Moderate fever (≥ 38.5°C)")
    elif data["temperature"] < 36.0:
        signals.append("⚠️  Hypothermia (< 36°C)")
    
    # Pain scale
    if data["pain_scale"] >= 9:
        signals.append("⚠️  CRITICAL: Severe pain (9-10/10)")
        critical_count += 1
    elif data["pain_scale"] >= 7:
        signals.append("⚠️  Significant pain (7-8/10)")
    elif data["pain_scale"] >= 4:
        signals.append("Moderate pain (4-6/10)")
    
    # Waiting time
    if data["waiting_time"] > 60:
        signals.append("⚠️  Prolonged waiting time (> 1 hour)")
    elif data["waiting_time"] > 30:
        signals.append("Extended waiting time (> 30 minutes)")
    
    # Age considerations
    if data["age"] >= 75:
        signals.append("👴 Elderly patient (≥ 75 years) - increased risk")
    elif data["age"] >= 65:
        signals.append("Older adult (65-74 years)")
    
    # Complaint category interpretation
    complaint_map = {
        0: "General complaint",
        1: "Respiratory issue",
        2: "Chest pain/cardiac",
        3: "Trauma/injury"
    }
    complaint = complaint_map.get(int(data.get("complaint_encoded", 0)), "Unknown")
    signals.append(f"Chief complaint: {complaint}")
    
    # Summary
    if critical_count >= 2:
        signals.insert(0, "🚨 MULTIPLE CRITICAL INDICATORS PRESENT")
    
    return signals if signals else ["All vital signs within normal range"]

# =========================
# Gemini Explanation Agent
# =========================

# =========================
# Enhanced Gemini Explanation Agent
# =========================

def gemini_explain(patient_data, risk_prob, decision, signals):
    """Generate clinical explanation using Gemini AI"""
    
    # Build comprehensive prompt
    prompt = f"""You are an experienced emergency medicine physician reviewing an AI triage decision.

PATIENT PROFILE:
• Age: {patient_data['age']} years
• Heart Rate: {patient_data['heart_rate']} BPM
• Oxygen Saturation (SpO2): {patient_data['oxygen']}%
• Body Temperature: {patient_data['temperature']}°C
• Pain Scale: {patient_data['pain_scale']}/10
• Waiting Time: {patient_data['waiting_time']} minutes
• Chief Complaint: {['General', 'Respiratory', 'Cardiac/Chest Pain', 'Trauma'][int(patient_data.get('complaint_encoded', 0))]}

AI ASSESSMENT:
• Risk Probability: {risk_prob:.1%}
• Classification: {decision}

KEY CLINICAL INDICATORS:
{chr(10).join('• ' + s for s in signals)}

As a senior clinician, provide a concise 3-part explanation (max 150 words total):

1. **Clinical Rationale**: Why this risk level makes sense given the patient's presentation
2. **Critical Factors**: Which 2-3 vital signs or symptoms drove this assessment  
3. **Immediate Actions**: Specific next steps for the triage team

Use professional medical terminology but keep it concise and actionable for an emergency department."""

    # Fallback if Gemini unavailable
    if client is None:
        return _generate_fallback_explanation(patient_data, risk_prob, decision, signals)

    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt
        )
        return response.text.strip()
    
    except Exception as e:
        print(f"⚠️  Gemini API error: {e}")
        return _generate_fallback_explanation(patient_data, risk_prob, decision, signals)

def _generate_fallback_explanation(patient_data, risk_prob, decision, signals):
    """Local rule-based explanation when Gemini is unavailable"""
    critical_signals = [s for s in signals if '⚠️' in s or '🚨' in s]
    
    explanation = f"""**Clinical Rationale**: Predicted risk probability of {risk_prob:.1%} ({decision}). """
    
    if risk_prob >= 0.8:
        explanation += "Patient presents with multiple high-risk indicators requiring immediate medical evaluation. "
    elif risk_prob >= 0.4:
        explanation += "Patient shows concerning vital signs that warrant close monitoring. "
    else:
        explanation += "Patient's vital signs are relatively stable but require routine assessment. "
    
    explanation += f"\n\n**Critical Factors**: {', '.join(critical_signals[:3]) if critical_signals else 'No immediate critical indicators'}. "
    
    if risk_prob >= 0.8:
        explanation += "\n\n**Immediate Actions**: Priority triage to resuscitation bay. Initiate continuous monitoring. Obtain IV access and prepare for rapid intervention."
    elif risk_prob >= 0.4:
        explanation += "\n\n**Immediate Actions**: Fast-track to assessment area. Obtain full vital signs every 15 minutes. Alert physician for evaluation within 30 minutes."
    else:
        explanation += "\n\n**Immediate Actions**: Standard triage flow. Reassess if waiting time exceeds 60 minutes or patient condition changes."
    
    return explanation

# =========================
# Enhanced Prediction Pipeline
# =========================

def predict_patient(patient_data):
    """Complete prediction pipeline with AI + Gemini explanation"""
    # Prepare features
    df = pd.DataFrame([patient_data], columns=FEATURES)
    scaled = scaler.transform(df)

    # AI Prediction
    prob = float(model.predict(scaled, verbose=0)[0][0])
    decision = risk_level(prob)
    signals = extract_signals(patient_data)

    # Gemini Explanation (agentic layer)
    explanation = gemini_explain(
        patient_data,
        prob,
        decision,
        signals
    )

    return {
        "risk_probability": prob,
        "decision": decision,
        "signals": signals,
        "gemini_explanation": explanation,
        "model_version": MODEL_VERSION,
        "timestamp": datetime.utcnow().isoformat()
    }

# =========================
# Human-in-the-Loop Feedback System
# =========================

def save_feedback(patient_data, ai_result, clinician_decision=None, clinician_notes=None):
    """Log patient records and clinician feedback for model retraining"""
    log = {
        "timestamp": datetime.utcnow().isoformat(),
        "model_version": MODEL_VERSION,
        "patient_data": patient_data,
        "ai_risk_probability": ai_result["risk_probability"],
        "ai_decision": ai_result["decision"],
        "ai_signals": ai_result["signals"],
        "ai_explanation": ai_result["gemini_explanation"],
        "clinician_decision": clinician_decision,
        "clinician_notes": clinician_notes,
        "agreement": clinician_decision == ai_result["decision"] if clinician_decision else None
    }

    with open(FEEDBACK_LOG_PATH, "a", encoding="utf-8") as f:
        f.write(json.dumps(log, ensure_ascii=False) + "\n")
    
    print(f"✅ Feedback logged for {ai_result['decision']}")

def analyze_feedback():
    """Analyze model performance from feedback logs"""
    if not os.path.exists(FEEDBACK_LOG_PATH):
        print("No feedback data available")
        return
    
    records = []
    with open(FEEDBACK_LOG_PATH, 'r', encoding='utf-8') as f:
        for line in f:
            records.append(json.loads(line))
    
    print(f"\n{'='*60}")
    print(f"📊 Feedback Analysis ({len(records)} records)")
    print(f"{'='*60}\n")
    
    agreements = [r for r in records if r.get('agreement') is not None]
    if agreements:
        agree_rate = sum(1 for r in agreements if r['agreement']) / len(agreements)
        print(f"Clinician-AI Agreement Rate: {agree_rate:.1%}")
        print(f"Total Overrides: {sum(1 for r in agreements if not r['agreement'])}")
    
    # Distribution by risk category
    decisions = [r['ai_decision'] for r in records]
    from collections import Counter
    decision_counts = Counter(decisions)
    print(f"\nDecision Distribution:")
    for decision, count in decision_counts.most_common():
        print(f"  {decision}: {count} ({count/len(records):.1%})")

# =========================
# CLI Interface & Testing
# =========================

def main():
    """Main CLI interface for training and inference"""
    import sys
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "train":
            print("🎯 Starting fresh training...")
            train_model(retrain=False)
        
        elif command == "retrain":
            print("🔄 Retraining with feedback data...")
            train_model(retrain=True)
        
        elif command == "analyze":
            analyze_feedback()
        
        elif command == "predict":
            # Interactive prediction mode
            print("\n=== Interactive Triage Prediction ===\n")
            patient = {
                "age": float(input("Age: ")),
                "heart_rate": float(input("Heart Rate (BPM): ")),
                "oxygen": float(input("Oxygen Saturation (%): ")),
                "temperature": float(input("Temperature (°C): ")),
                "pain_scale": float(input("Pain Scale (0-10): ")),
                "waiting_time": float(input("Waiting Time (min): ")),
                "complaint_encoded": float(input("Complaint (0=General, 1=Respiratory, 2=Cardiac, 3=Trauma): "))
            }
            
            result = predict_patient(patient)
            print_prediction_result(result)
            
            override = input("\nClinician Override (enter decision or press Enter to skip): ").strip()
            if override:
                save_feedback(patient, result, clinician_decision=override)
        
        else:
            print(f"Unknown command: {command}")
            print("Available commands: train, retrain, analyze, predict")
    
    else:
        # Run demo prediction
        run_demo()

def print_prediction_result(result):
    """Pretty print prediction results"""
    print(f"\n{'='*60}")
    print("🏥 AI TRIAGE RESULT")
    print(f"{'='*60}\n")
    print(f"Risk Probability: {result['risk_probability']:.1%}")
    print(f"Decision: {result['decision']}")
    print(f"Model Version: {result['model_version']}")
    print(f"\n{'─'*60}")
    print("📋 Key Clinical Signals:")
    print(f"{'─'*60}")
    for signal in result["signals"]:
        print(f"  • {signal}")
    
    print(f"\n{'─'*60}")
    print("🤖 Gemini Clinical Explanation:")
    print(f"{'─'*60}")
    print(result["gemini_explanation"])
    print(f"{'='*60}\n")

def run_demo():
    """Run demonstration with sample patient"""
    sample_patient = {
        "age": 65,
        "heart_rate": 120,
        "oxygen": 89,
        "temperature": 38.5,
        "pain_scale": 8,
        "waiting_time": 45,
        "complaint_encoded": 2
    }

    ai_result = predict_patient(sample_patient)
    print_prediction_result(ai_result)

    save_feedback(
        sample_patient,
        ai_result,
        clinician_decision="HIGH RISK - Immediate attention",
        clinician_notes="Patient sent to resuscitation bay - confirmed MI"
    )

if __name__ == "__main__":
    main()
