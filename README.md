<h1 align="center">🩺 KitaHack — Triage AI (Monorepo)</h1>

<p align="center">
  <strong>Offline-first, human-in-the-loop AI triage system for emergency care</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-Mobile-blue" />
  <img src="https://img.shields.io/badge/TensorFlow-Lite-orange" />
  <img src="https://img.shields.io/badge/Firebase-Realtime-yellow" />
  <img src="https://img.shields.io/badge/Google%20Gemini-Explainable%20AI-purple" />
</p>

<hr/>

## 🧠 Overview

**KitaHack — Triage AI** is a hackathon MVP that demonstrates how **edge AI**, **generative AI**, and **human-in-the-loop workflows** can be combined to build a **safe, explainable, and realistic clinical triage system**.

The system predicts patient risk locally on-device using a **TensorFlow Lite model**, while optionally using **Google Gemini (AI Studio)** to generate clinician-friendly explanations.  
All decisions remain under **human control**, following responsible and ethical AI principles.

---

## 🎯 Key Features

<ul>
  <li>📱 <strong>Offline-first AI inference</strong> using TensorFlow Lite (no internet required for risk prediction)</li>
  <li>🧠 <strong>Explainable AI (XAI)</strong> via Google Gemini for clinical reasoning</li>
  <li>🧑‍⚕️ <strong>Human-in-the-loop triage</strong> with clinician overrides</li>
  <li>⚡ <strong>Real-time queue updates</strong> using Firebase Firestore</li>
  <li>🔔 <strong>Critical notifications</strong> with severity-based alerts</li>
  <li>🔁 <strong>Feedback-driven retraining</strong> pipeline (offline Python)</li>
</ul>

---

## 🏗️ Planned Architecture

Flutter Mobile App
 ├─ Local TFLite Risk Model (Edge AI)
 ├─ Patient Input + Simulation
 ├─ Clinician Override UI
 └─ Real-time Queue View
        ↓
Firebase
 ├─ Firestore (Queue, Logs, Feedback)
 ├─ Cloud Functions (Priority Logic, Safety Rules)
 ├─ Cloud Messaging (Alerts)
 └─ Hosting (Optional Dashboard)
        ↓
Google AI Studio (Gemini)
 └─ Clinical Explanation & Reasoning (Optional)
        ↓
Offline Python Pipeline
 └─ Retraining → Export → TFLite
🛠️ Tech Stack
Mobile

Flutter

TensorFlow Lite

Material UI (custom modern theme)

Backend / Cloud

Firebase Firestore (real-time database)

Firebase Cloud Functions (AI orchestration & safety logic)

Firebase Cloud Messaging (notifications)

Firebase Storage (logs & artifacts)

AI & ML

TensorFlow / Keras

Scikit-learn

Google Gemini (AI Studio) for explanations

Rule-based clinical safety signals

🚀 Getting Started
1️⃣ Run the Flutter App
cd mobile
cd flutter
flutter run


Requires Flutter SDK and a connected emulator or device.

2️⃣ Run the Python AI Server (Inference / Demo)
cd "c:/Users/User/Desktop/Project/KitaHack" && \
C:/Users/User/Desktop/Project/KitaHack/.venv/Scripts/python.exe model_server.py


Handles prediction logic, explanations, and feedback logging.

3️⃣ Train / Retrain the ML Model
cd "c:/Users/User/Desktop/Project/KitaHack" && \
C:/Users/User/Desktop/Project/KitaHack/.venv/Scripts/python.exe main.py train


Available commands:

train — fresh training

retrain — retrain using clinician feedback

analyze — analyze feedback & agreement rate

predict — interactive CLI prediction

🔁 Human-in-the-Loop Workflow

AI predicts patient risk (offline)

Gemini generates explanation (optional)

Clinician reviews decision

Clinician may override priority

Feedback is logged for future retraining

AI assists clinicians — it does not replace them.

🔐 Responsible AI & Safety
<ul> <li>Human decisions always override AI</li> <li>No automated clinical decisions</li> <li>Explainability by default</li> <li>Audit logs for all overrides</li> <li>Offline-first for resilience</li> </ul>
📈 Future Work

Vertex AI for scalable retraining

BigQuery analytics for model drift

Role-based clinician access

Multi-language explanations (EN/BM)

Hospital dashboard (Firebase Hosting)

🏆 Hackathon Pitch Summary

“KitaHack — Triage AI combines edge-based machine learning, generative AI explanations, and human-in-the-loop decision-making to deliver a safe, explainable, and production-ready AI triage system for emergency healthcare.”
