import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/patient_simulator.dart';
import '../services/model_service.dart';
import '../services/notification_service.dart';
import 'queue_detail_screen.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  Timer? _timer;
  bool _autoGenerating = false;
  bool _isGenerating = false;
  // Audio disabled (requires NDK). Alerts use print() only.
  int _lastCount = 0;

  void _toggleAutoGenerate() {
    if (_autoGenerating) {
      _stopAutoGenerate();
    } else {
      _startAutoGenerate();
    }
    setState(() {
      _autoGenerating = !_autoGenerating;
    });
  }

  void _startAutoGenerate() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_isGenerating) return;
      _isGenerating = true;
      try {
        final patient = PatientSimulator.instance.generatePatient();
        final features = <String, double>{
          'age': (patient['age'] ?? 50).toDouble(),
          'oxygen': (patient['oxygen'] ?? 98).toDouble(),
          'heart_rate': (patient['heart_rate'] ?? 80).toDouble(),
          'pain_scale': (patient['pain_scale'] ?? 0).toDouble(),
          'temperature': (patient['temperature'] ?? 37).toDouble(),
          'waiting_time': (patient['waiting_time'] ?? 0).toDouble(),
          'complaint_encoded': (patient['complaint_encoded'] ?? 0).toDouble(),
        };

        final prob = await ModelService.instance.predict(features);
        await FirestoreService.instance.enqueuePatient(patient, prob);
      } catch (e) {
        print('Auto-generate error: $e');
      }
      _isGenerating = false;
    });
  }

  void _stopAutoGenerate() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopAutoGenerate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF4FA3D1),
        title: const Text(
          'Patient Queue',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: Colors.white),
            onPressed: () {},
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(_autoGenerating ? Icons.stop : Icons.play_arrow,
                color: Colors.white),
            onPressed: _toggleAutoGenerate,
            tooltip:
                _autoGenerating ? 'Stop auto-generate' : 'Start auto-generate',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.instance.queueStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Error loading queue'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;

          // Play alert when new patient arrives and send notification
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              if (_lastCount < docs.length) {
                // new item(s) added; check most recent doc (sorted by risk)
                final recent = docs.first.data() as Map<String, dynamic>;
                final aiRecent = recent['ai_result'] ?? {};
                final probRecent =
                    (aiRecent['risk_probability'] ?? 0.0) as double;
                final patientData = recent['patient_data'] ?? {};

                // Play alert
                _playAlert(probRecent >= 0.8);

                // Send push notification
                if (probRecent >= 0.8) {
                  NotificationService.instance.showCriticalPatientAlert(
                    patientName: patientData['name'] ?? 'Unknown',
                    riskProbability: probRecent,
                    patientId: docs.first.id,
                  );
                } else if (probRecent >= 0.4) {
                  NotificationService.instance.showUrgentPatientAlert(
                    patientName: patientData['name'] ?? 'Unknown',
                    riskProbability: probRecent,
                    patientId: docs.first.id,
                  );
                }
              }
            } catch (e) {
              print('Alert check error: $e');
            }
            _lastCount = docs.length;
          });
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDEF0FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: const Color(0xFF4FA3D1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No patients in queue',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'All patients have been processed',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final ai = d['ai_result'] ?? {};
              final prob = (ai['risk_probability'] ?? 0.0) as double;
              final patient = d['patient_data'] ?? {};

              final Color riskColor = prob >= 0.8
                  ? const Color(0xFFDC2626)
                  : (prob >= 0.4 ? const Color(0xFFEA580C) : const Color(0xFF16A34A));
              final String riskLabel = prob >= 0.8
                  ? 'Critical'
                  : (prob >= 0.4 ? 'Urgent' : 'Stable');

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QueueDetailScreen(
                        docId: docs[i].id,
                        data: d,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Patient #${docs[i].id.substring(0, 5).toUpperCase()}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.medical_information_outlined,
                                            size: 14,
                                            color: const Color(0xFF4FA3D1),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              patient['complaint'] ?? 'No symptoms',
                                              style: const TextStyle(
                                                color: Color(0xFF64748B),
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: riskColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: riskColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${(prob * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          color: riskColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        riskLabel,
                                        style: TextStyle(
                                          color: riskColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Waiting: ${patient['waiting_time'] ?? 0} min',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Age: ${patient['age'] ?? '--'}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remove Patient'),
                                content: const Text(
                                    'Remove this patient from the queue?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await FirestoreService.instance
                                    .deletePatient(docs[i].id);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to remove patient'),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(8),
                              ),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _playAlert(bool critical) async {
    // Play system alert sound and vibration (works on real devices and emulators)
    try {
      // Vibrate for haptic feedback
      if (critical) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
      // Play system sound
      await SystemSound.play(SystemSoundType.alert);
      print(
          '🔔 ALERT: ${critical ? "⚠️ CRITICAL" : "ℹ️ Normal"} patient added to queue');

      // Visual alert for emulators (sound may not work)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(critical ? Icons.warning : Icons.info,
                    color: Colors.white),
                const SizedBox(width: 8),
                Text(critical ? '⚠️ CRITICAL Patient' : 'New Patient'),
              ],
            ),
            backgroundColor:
                critical ? Colors.red.shade700 : Colors.blue.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('🔔 Alert failed: $e');
    }
  }
}
