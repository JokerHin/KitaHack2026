🏥 KitaHack — Triage AI (Monorepo)

KitaHack — Triage AI is a triage decision-support MVP designed to assist clinicians in prioritising patients using a combination of on-device machine learning, cloud-based workflows, and optional AI-generated explanations.
The system focuses on speed, transparency, and clinician control, making it suitable for real-world healthcare constraints.

This repository is a monorepo containing the mobile app, backend services, and machine learning pipeline.

✨ Key Features

📱 Flutter mobile app with offline-first triage scoring

🧠 On-device TFLite model for fast and private predictions

🩺 Clinician override support for human-in-the-loop decision making

📊 Firebase-backed queue & logs for auditability

🤖 Optional Gemini explanations via Google AI Studio

🔁 Retraining pipeline using real feedback data

🧩 Planned Architecture Overview
Mobile (Flutter)

Runs a local TensorFlow Lite (TFLite) model

Collects patient inputs (symptoms, vitals, metadata)

Allows clinician overrides on AI priority

Displays prediction explanations for transparency

Works even with limited or no connectivity

Firebase

Firestore: patient queue, prediction logs, clinician feedback

Firebase Auth: clinician authentication

Cloud Functions: priority logic, validation, queue updates

Firebase Hosting: admin / dashboard interface (optional)

AI Explanation (Optional)

Google AI Studio (Gemini) used to generate richer, human-readable explanations

Called only when network is available

Not required for core triage functionality

Model Retraining

Offline Python ML pipeline

Uses logged feedback to improve model accuracy

Retrains and exports updated TFLite models for mobile deployment

📄 See docs/architecture.md
for detailed diagrams and next steps.

📁 Repository Structure
KitaHack/
├── mobile/
│ └── flutter/ # Flutter mobile application
├── model_server.py # Local Python inference / testing server
├── main.py # ML training pipeline
├── docs/
│ └── architecture.md
├── .venv/ # Python virtual environment
└── README.md

🚀 Getting Started
Prerequisites

Flutter (stable channel)

Android Studio or Android SDK

Python 3.10+

Virtual environment set up (.venv)

Firebase project (for cloud features)

📱 Run the Flutter App
cd mobile
cd flutter
flutter run

Make sure an emulator or physical device is connected.

🧪 Run the Python Model Server

Used for local testing and experimentation.

cd "c:/Users/User/Desktop/Project/KitaHack" && \
C:/Users/User/Desktop/Project/KitaHack/.venv/Scripts/python.exe model_server.py

🧠 Train the Machine Learning Model

This retrains the triage model using collected data and exports an updated version.

cd "c:/Users/User/Desktop/Project/KitaHack" && \
C:/Users/User/Desktop/Project/KitaHack/.venv/Scripts/python.exe main.py train

🔐 Human-in-the-Loop Design

This system is not fully autonomous by design.

AI provides recommendations

Clinicians review and override

All decisions are logged for audit and retraining

This ensures safety, accountability, and real clinical usability.

🛠 Tech Stack

Frontend: Flutter

ML: TensorFlow / TFLite, Python

Backend: Firebase (Firestore, Auth, Functions)

AI (Optional): Google Gemini (AI Studio)

Deployment: Android (initial), extensible to iOS

📌 Status

🚧 MVP / Hackathon Stage
Core features are under active development. Architecture is designed to scale into production with minimal changes.
