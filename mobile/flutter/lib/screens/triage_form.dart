import 'package:flutter/material.dart';
import '../services/model_service.dart';
import '../services/firestore_service.dart';
import '../services/patient_simulator.dart';

class TriageFormScreen extends StatefulWidget {
  const TriageFormScreen({super.key});

  @override
  State<TriageFormScreen> createState() => _TriageFormScreenState();
}

class _TriageFormScreenState extends State<TriageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, double> _values = {
    'age': 45,
    'heart_rate': 80,
    'oxygen': 98,
    'temperature': 37.0,
    'pain_scale': 0,
    'waiting_time': 5,
    'complaint_encoded': 0,
  };

  String _result = '';
  bool _loading = false;
  double _riskScore = 0.0;
  String _patientName = 'Patient';
  String _complaint = 'General';

  void _simulatePatient() {
    final patient = PatientSimulator.instance.generatePatient();

    setState(() {
      _values['age'] = patient['age']!;
      _values['heart_rate'] = patient['heart_rate']!;
      _values['oxygen'] = patient['oxygen']!;
      _values['temperature'] = patient['temperature']!;
      _values['pain_scale'] = patient['pain_scale']!;
      _values['waiting_time'] = 0;
      _values['complaint_encoded'] = 0;
      _patientName = patient['name'] as String? ?? 'Patient';
      _complaint = patient['complaint'] as String? ?? 'General';
      _result = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated patient: $_patientName'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _loading = true;
      _result = '';
    });

    try {
      final prob = await ModelService.instance.predict(_values);
      await FirestoreService.instance.enqueuePatient(Map.from(_values), prob);

      setState(() {
        _loading = false;
        _riskScore = prob;
        _result =
            (prob >= 0.8) ? 'CRITICAL' : (prob >= 0.4 ? 'URGENT' : 'STABLE');
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _result = 'Submission failed';
      });
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 16, left: 20, right: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _inputCard(
      {required String label, required Widget child, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF1976D2)),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: const Text('Patient Assessment'),
        ),
        body: SingleChildScrollView(
          child: Column(children: [
            // Clean Simulate Patient Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: Colors.white,
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: _simulatePatient,
                    icon: const Icon(Icons.shuffle, size: 18),
                    label: const Text(
                      'Generate Sample Patient',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Patient Info
                  if (_patientName != 'Patient')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _patientName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  _complaint,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Form Content
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Info Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 28,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _patientName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _complaint,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    _sectionTitle('Vital Signs'),
                    _inputCard(
                      label: 'Oxygen Saturation (SpO2)',
                      icon: Icons.air,
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _values['oxygen']!,
                              min: 70,
                              max: 100,
                              divisions: 30,
                              label: _values['oxygen']!.round().toString(),
                              onChanged: (v) =>
                                  setState(() => _values['oxygen'] = v),
                            ),
                          ),
                          Text('${_values['oxygen']!.round()}%',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _inputCard(
                            label: 'Heart Rate',
                            icon: Icons.favorite,
                            child: TextFormField(
                              initialValue:
                                  _values['heart_rate']!.toInt().toString(),
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(suffixText: 'BPM'),
                              onSaved: (v) => _values['heart_rate'] =
                                  double.tryParse(v ?? '') ?? 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _inputCard(
                            label: 'Temp',
                            icon: Icons.thermostat,
                            child: TextFormField(
                              initialValue: _values['temperature']!.toString(),
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(suffixText: '°C'),
                              onSaved: (v) => _values['temperature'] =
                                  double.tryParse(v ?? '') ?? 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _sectionTitle('Patient Status'),
                    _inputCard(
                      label: 'Pain Scale (0-10)',
                      icon: Icons.bolt,
                      child: Slider(
                        value: _values['pain_scale']!,
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: _values['pain_scale']!.toInt().toString(),
                        onChanged: (v) =>
                            setState(() => _values['pain_scale'] = v),
                      ),
                    ),
                    _inputCard(
                      label: 'Age',
                      icon: Icons.person,
                      child: TextFormField(
                        initialValue: _values['age']!.toInt().toString(),
                        keyboardType: TextInputType.number,
                        onSaved: (v) =>
                            _values['age'] = double.tryParse(v ?? '') ?? 0,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.analytics, size: 24),
                          label: const Text(
                            'ANALYZE RISK',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            elevation: 2,
                          ),
                        ),
                      ),

                    // Results Card
                    if (_result.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _riskScore >= 0.8
                                ? [
                                    const Color(0xFFE53935),
                                    const Color(0xFFD32F2F)
                                  ]
                                : (_riskScore >= 0.4
                                    ? [
                                        const Color(0xFFFB8C00),
                                        const Color(0xFFF57C00)
                                      ]
                                    : [
                                        const Color(0xFF43A047),
                                        const Color(0xFF388E3C)
                                      ]),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (_riskScore >= 0.8
                                      ? Colors.red
                                      : (_riskScore >= 0.4
                                          ? Colors.orange
                                          : Colors.green))
                                  .withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _riskScore >= 0.8
                                    ? Icons.warning_rounded
                                    : (_riskScore >= 0.4
                                        ? Icons.info_rounded
                                        : Icons.check_circle_rounded),
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'TRIAGE PRIORITY',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _result,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                'Risk Score: ${(_riskScore * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ]),
        ));
  }
}
