KitaHack — Triage AI (Monorepo)

This repository contains components for a triage AI MVP and related infrastructure.

Planned architecture:

- Mobile (Flutter): local TFLite model, UI to send patient data + clinician overrides, shows explanations
- Firebase: Firestore (queue + logs), Auth (clinicians), Cloud Functions (priority logic), Hosting (dashboard)
- Google AI Studio: optional explanation service (Gemini) for richer explanations
- Retraining: offline Python pipeline using feedback logs to retrain/export TFLite model

See `docs/architecture.md` for details and next steps.
