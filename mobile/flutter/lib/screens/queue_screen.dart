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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Live Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {},
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(_autoGenerating ? Icons.stop : Icons.play_arrow),
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
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: const Color(0xFF64748B).withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No patients in queue',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'All clear',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
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
                  ? Colors.red
                  : (prob >= 0.4 ? Colors.orange : Colors.green);

              return InkWell(
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        prob >= 0.8
                            ? Colors.red.withOpacity(0.02)
                            : (prob >= 0.4
                                ? Colors.orange.withOpacity(0.02)
                                : Colors.green.withOpacity(0.02)),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          decoration: BoxDecoration(
                            color: riskColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Patient #${docs[i].id.substring(0, 5)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: riskColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${(prob * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          color: riskColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    _vitalBadge(
                                        Icons.air, '${patient['oxygen']}%'),
                                    _vitalBadge(Icons.favorite,
                                        '${patient['heart_rate']}'),
                                    _vitalBadge(Icons.thermostat,
                                        '${patient['temperature']}°C'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.grey),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete patient'),
                                    content: const Text(
                                        'Remove this patient from the queue?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await FirestoreService.instance
                                        .deletePatient(docs[i].id);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Delete failed')));
                                  }
                                }
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child:
                                  Icon(Icons.chevron_right, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _vitalBadge(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
      ],
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
