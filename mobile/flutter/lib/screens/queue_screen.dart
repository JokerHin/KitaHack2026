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
  final String? filterLevel;

  const QueueScreen({
    super.key,
    this.filterLevel,
  });

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  Timer? _timer;
  bool _autoGenerating = false;
  bool _isGenerating = false;
  // Audio disabled (requires NDK). Alerts use print() only.
  int _lastCount = 0;

  bool _isCriticalAndWaitingTooLong(Map<String, dynamic> data) {
    final ai = data['ai_result'] ?? {};
    final prob = (ai['risk_probability'] ?? 0.0) as double;
    
    // Only for critical patients
    if (prob < 0.8) return false;
    
    // Check waiting time (handle both int and double)
    final patient = data['patient_data'] ?? {};
    final waitingTimeRaw = patient['waiting_time'] ?? 0;
    final waitingTime = waitingTimeRaw is int ? waitingTimeRaw : (waitingTimeRaw as double).toInt();
    
    // If waiting time > 5 minutes (300 seconds)
    return waitingTime > 300;
  }

  // Get critical patients waiting too long
  Map<String, dynamic>? _getCriticalWaitingPatient(List<QueryDocumentSnapshot> docs) {
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      if (_isCriticalAndWaitingTooLong(d)) {
        final patient = d['patient_data'] ?? {};
        final waitingTimeRaw = patient['waiting_time'] ?? 0;
        final waitingTime = waitingTimeRaw is int ? waitingTimeRaw : (waitingTimeRaw as double).toInt();
        final waitingMinutes = (waitingTime / 60).ceil();
        return {
          'id': doc.id,
          'name': (patient['name'] ?? 'Unknown').toString(),
          'waitingMinutes': waitingMinutes,
        };
      }
    }
    return null;
  }

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
        title: Text(
          widget.filterLevel != null
              ? 'Patients - ${widget.filterLevel!.replaceFirst(widget.filterLevel![0], widget.filterLevel![0].toUpperCase())}'
              : 'Patient Queue',
          style: const TextStyle(
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
          var docs = snap.data!.docs;

          // Apply filter based on filterLevel
          if (widget.filterLevel != null) {
            docs = docs.where((d) {
              final prob = (d['ai_result']?['risk_probability'] ?? 0.0) as double;
              switch (widget.filterLevel) {
                case 'critical':
                  return prob >= 0.8;
                case 'urgent':
                  return prob >= 0.4 && prob < 0.8;
                case 'stable':
                  return prob < 0.4;
                default:
                  return true;
              }
            }).toList();
          }

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

          // Check for critical patients waiting too long
          final criticalWaiting = _getCriticalWaitingPatient(docs);

          return Column(
            children: [
              // Show banner if critical patient waiting too long
              if (criticalWaiting != null)
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_rounded,
                          color: Color(0xFFDC2626),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '⚠️ Critical Patient Alert',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${criticalWaiting['name']} has been waiting for ${criticalWaiting['waitingMinutes']} minutes',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.access_time,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Patient queue list
              Expanded(
                child: ListView.builder(
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

                    return Dismissible(
                      key: Key(docs[i].id),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(
                          Icons.delete_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Remove Patient'),
                            content: Text(
                              'Remove Patient #${docs[i].id.substring(0, 5).toUpperCase()} from the queue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                ),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                        return confirm ?? false;
                      },
                      onDismissed: (direction) async {
                        try {
                          await FirestoreService.instance.deletePatient(docs[i].id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Patient removed from queue'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to remove patient'),
                              ),
                            );
                          }
                        }
                      },
                      child: GestureDetector(
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
                          child: Padding(
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
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
