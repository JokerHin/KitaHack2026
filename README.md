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

<pre>
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
 </pre>
<hr/>

<h2>🛠️ Tech Stack</h2>

<h3>📱 Mobile Application</h3>
<ul>
  <li><strong>Flutter</strong> — cross-platform mobile framework</li>
  <li><strong>TensorFlow Lite</strong> — on-device machine learning inference</li>
  <li><strong>Dart</strong> — application logic and UI</li>
  <li><strong>Material UI</strong> — modern, clinician-friendly interface</li>
</ul>

<hr/>

<h3>🧠 Machine Learning & AI</h3>
<ul>
  <li><strong>TensorFlow / Keras</strong> — neural network training</li>
  <li><strong>Scikit-learn</strong> — preprocessing, scaling, evaluation</li>
  <li><strong>Tabular Clinical Data Modeling</strong></li>
  <li><strong>Explainable AI (XAI)</strong> — risk reasoning & transparency</li>
  <li><strong>Google Gemini (AI Studio)</strong> — clinical explanation generation</li>
</ul>

<hr/>

<h3>☁️ Backend & Cloud</h3>
<ul>
  <li><strong>Firebase Firestore</strong> — real-time database for queue & logs</li>
  <li><strong>Firebase Cloud Functions</strong> — secure AI orchestration</li>
  <li><strong>Firebase Cloud Messaging</strong> — critical alerts & notifications</li>
  <li><strong>Firebase Storage</strong> — audit artifacts & logs</li>
  <li><strong>Firebase Hosting</strong> — optional dashboard hosting</li>
</ul>

<hr/>

<h3>🔁 MLOps & Model Lifecycle</h3>
<ul>
  <li><strong>Offline Training Pipeline (Python)</strong></li>
  <li><strong>Human-in-the-Loop Feedback Logging</strong></li>
  <li><strong>Model Versioning</strong></li>
  <li><strong>Retraining & TFLite Export</strong></li>
  <li><strong>Performance Evaluation (ROC-AUC, Precision, Recall)</strong></li>
</ul>

<hr/>

<h3>🔐 Responsible AI & Safety</h3>
<ul>
  <li><strong>Human-in-the-Loop Design</strong></li>
  <li><strong>Clinician Override Mechanism</strong></li>
  <li><strong>Audit Logs & Traceability</strong></li>
  <li><strong>Offline-First Architecture</strong></li>
  <li><strong>Explainability by Default</strong></li>
</ul>


<h2>🚀 Getting Started</h2>

<h3>1️⃣ Run the Flutter Mobile App</h3>

<pre>
cd mobile
cd flutter
flutter run
</pre>

<p>
Runs the Flutter application with on-device TensorFlow Lite inference.
The app supports manual patient input and AI-generated patient simulation.
</p>

<hr/>

<h3>2️⃣ Run the Python AI Server (Inference & Explanation)</h3>

<pre>
cd "c:/Users/User/Desktop/Project/KitaHack" && 
C:/Users/User/Desktop/Project/KitaHack/.venv/Scripts/python.exe model_server.py
</pre>

<p>
This service handles:
</p>

<ul>
  <li>AI risk prediction</li>
  <li>Clinical signal extraction</li>
  <li>Gemini-powered explanations (optional)</li>
  <li>Human feedback logging</li>
</ul>

<hr/>

<h3>3️⃣ Train or Retrain the Machine Learning Model</h3>

<pre>
cd "c:/Users/User/Desktop/Project/KitaHack" && 
C:/Users/User/Desktop/Project/KitaHack/.venv/Scripts/python.exe main.py train
</pre>

<p>Available commands:</p>

<ul>
  <li><strong>train</strong> — fresh model training</li>
  <li><strong>retrain</strong> — retrain using clinician feedback</li>
  <li><strong>analyze</strong> — analyze feedback & agreement rate</li>
  <li><strong>predict</strong> — interactive CLI prediction</li>
</ul>

<hr/>

<h2>🔁 Human-in-the-Loop Workflow</h2>

<ol>
  <li>AI model predicts patient risk locally on-device</li>
  <li>Google Gemini generates a clinical explanation (optional)</li>
  <li>Clinician reviews AI recommendation</li>
  <li>Clinician may override the priority</li>
  <li>Override and notes are logged for audit and retraining</li>
</ol>

<p>
<strong>Design principle:</strong> AI provides decision support, but clinicians always make the final decision.
</p>

<hr/>

<h2>🔔 Notification & Alert System</h2>

<ul>
  <li>Real-time queue updates via Firestore streams</li>
  <li>Audio alerts for new patients</li>
  <li>Critical alert sound for high-risk cases</li>
  <li>Push notifications via Firebase Cloud Messaging</li>
</ul>

<hr/>

<h2>🔐 Responsible AI & Safety</h2>

<ul>
  <li>No fully automated clinical decisions</li>
  <li>Human-in-the-loop override by design</li>
  <li>Explainable AI for transparency</li>
  <li>Audit logs for clinician actions</li>
  <li>Offline-first inference for reliability</li>
</ul>

<hr/>

<h2>📈 Future Improvements</h2>

<ul>
  <li>Vertex AI for large-scale retraining</li>
  <li>BigQuery analytics for model drift detection</li>
  <li>Multi-language support (English / Bahasa Malaysia)</li>
  <li>Role-based clinician access</li>
  <li>Web dashboard via Firebase Hosting</li>
</ul>

<hr/>

<h2>🏆 Hackathon Pitch Summary</h2>

<blockquote>
  KitaHack — Triage AI combines edge-based machine learning, generative AI explanations, and
  human-in-the-loop decision-making to deliver a safe, explainable, and production-ready
  AI triage system for emergency healthcare.
</blockquote>

<hr/>

<h2>📜 License</h2>

<p>
This project is built as a proof-of-concept MVP for <strong>KitaHack 2026</strong>.
</p>

