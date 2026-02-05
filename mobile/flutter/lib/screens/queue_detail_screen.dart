import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/model_service.dart';
import 'queue_chat_screen.dart';
import '../services/firestore_service.dart';

class QueueDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const QueueDetailScreen({super.key, required this.docId, required this.data});

  @override
  State<QueueDetailScreen> createState() => _QueueDetailScreenState();
}

class _QueueDetailScreenState extends State<QueueDetailScreen> {
  String _explanation = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExplanation();
  }

  Future<void> _loadExplanation() async {
    setState(() => _loading = true);
    try {
      final ai = widget.data['ai_result'] ?? {};
      final prob = (ai['risk_probability'] ?? 0.0) as double;
      final patient =
          (widget.data['patient_data'] ?? {}) as Map<String, dynamic>;
      final category = ModelService.instance.getRiskCategory(prob);

      final text = await GeminiService.instance.generateExplanation(
        patientData: patient,
        riskProbability: prob,
        riskCategory: category,
      );

      setState(() {
        _explanation = text;
      });
    } catch (e) {
      setState(() {
        _explanation = 'Unable to generate explanation.';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _getRiskColor(double prob) {
    if (prob >= 0.8) return const Color(0xFFDC2626);
    if (prob >= 0.4) return const Color(0xFFEA580C);
    return const Color(0xFF16A34A);
  }

  // Check if vital sign is abnormal
  bool _isAbnormal(String label, dynamic value) {
    if (value == null || value == '—') return false;
    
    try {
      switch (label) {
        case 'Heart Rate':
          final hr = (value is String) 
              ? double.parse(value.replaceAll(RegExp(r'[^0-9.]'), '')) 
              : (value as num).toDouble();
          return hr < 60 || hr > 100;
          
        case 'Oxygen Level':
          final o2 = (value is String) 
              ? double.parse(value.replaceAll(RegExp(r'[^0-9.]'), '')) 
              : (value as num).toDouble();
          return o2 < 95 || o2 > 100;
          
        case 'Temperature':
          final temp = (value is String) 
              ? double.parse(value.replaceAll(RegExp(r'[^0-9.]'), '')) 
              : (value as num).toDouble();
          return temp < 36.5 || temp > 37.5;
          
        case 'Pain Level':
          final pain = (value is String) 
              ? double.parse(value.replaceAll(RegExp(r'[^0-9.]'), '')) 
              : (value as num).toDouble();
          return pain > 3;
          
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = widget.data['ai_result'] ?? {};
    final prob = (ai['risk_probability'] ?? 0.0) as double;
    final patient = (widget.data['patient_data'] ?? {}) as Map<String, dynamic>;
    final category = ModelService.instance.getRiskCategory(prob);
    final riskColor = _getRiskColor(prob);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4FA3D1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Patient Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Remove Patient'),
                  content: const Text('Remove this patient from the queue?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Remove',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await FirestoreService.instance.deletePatient(widget.docId);
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to remove patient')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Patient header card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient name and risk badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient['name'] ?? 'Unknown Patient',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.medical_information_outlined,
                                  size: 14,
                                  color: Color(0xFF4FA3D1),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    patient['complaint'] ?? 'No complaint recorded',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
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
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: riskColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: riskColor, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${(prob * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: riskColor,
                              ),
                            ),
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: riskColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Vital signs section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vital Signs',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _vitalSignCard(
                        '❤️',
                        'Heart Rate',
                        '${patient['heart_rate'] ?? '—'} bpm',
                        const Color(0xFFDC2626),
                      ),
                      _vitalSignCard(
                        '💨',
                        'Oxygen Level',
                        '${patient['oxygen'] ?? '—'}%',
                        const Color(0xFF2563EB),
                      ),
                      _vitalSignCard(
                        '🌡️',
                        'Temperature',
                        patient['temperature'] != null
                            ? '${(patient['temperature'] as num).toStringAsFixed(1)}°C'
                            : '—°C',
                        const Color(0xFFF59E0B),
                      ),
                      _vitalSignCard(
                        '😣',
                        'Pain Level',
                        '${patient['pain_scale'] ?? '—'}/10',
                        const Color(0xFF9333EA),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Transfer Patient - Slide to Unlock Style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSlideToTransferButton(),
            ),
            const SizedBox(height: 20),

            // AI Assessment section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Assessment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                    child: _loading
                        ? Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(riskColor),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Analyzing patient data...',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _explanation,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loadExplanation,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Regenerate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4FA3D1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog(BuildContext context, String currentCategory) {
    final specialties = {
      'Cardiology': '❤️',
      'Orthopedics': '🦴',
      'Dermatology': '🩹',
      'Neurology': '🧠',
      'Gastroenterology': '🫘',
      'Pulmonology': '🫁',
      'Rheumatology': '🦵',
      'Endocrinology': '⚗️',
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer Patient'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: specialties.length,
            itemBuilder: (context, index) {
              final specialty = specialties.keys.elementAt(index);
              final emoji = specialties[specialty]!;
              return ListTile(
                leading: Text(
                  emoji,
                  style: const TextStyle(fontSize: 20),
                ),
                title: Text(specialty),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Patient transferred to $emoji $specialty',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _vitalSignCard(
    String emoji,
    String label,
    String value,
    Color color,
  ) {
    final isAbnormal = _isAbnormal(label, value);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAbnormal ? color : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isAbnormal ? Colors.white : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isAbnormal ? Colors.white : color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSlideToTransferButton() {
    final ai = widget.data['ai_result'] ?? {};
    final prob = (ai['risk_probability'] ?? 0.0) as double;
    final category = ModelService.instance.getRiskCategory(prob);
    final riskColor = _getRiskColor(prob);

    return Column(
      children: [
        // Slide to Transfer Button
        _SlideToTransferButton(
          onTransfer: () => _showTransferDialog(context, category),
          riskColor: riskColor,
        ),
        const SizedBox(height: 12),
        // Chat with AI Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QueueChatScreen(patient: widget.data['patient_data'] as Map<String, dynamic>? ?? {}),
                ),
              );
            },
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('Chat with AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FA3D1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SlideToTransferButton extends StatefulWidget {
  final VoidCallback onTransfer;
  final Color riskColor;

  const _SlideToTransferButton({
    required this.onTransfer,
    required this.riskColor,
  });

  @override
  State<_SlideToTransferButton> createState() => _SlideToTransferButtonState();
}

class _SlideToTransferButtonState extends State<_SlideToTransferButton> {
  late double _dragOffset;

  @override
  void initState() {
    super.initState();
    _dragOffset = 0;
  }

  void _resetSlide() {
    setState(() {
      _dragOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Highway length
          final double maxDragDistance = constraints.maxWidth - 48 - 8;

          return Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.riskColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.centerLeft, // Start from LEFT
              children: [
                // 1. Text Background (Cannot touch)
                Center(
                  child: Text(
                    'Slide to Transfer Patient',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: widget.riskColor.withOpacity(0.4),
                    ),
                  ),
                ),
                
                // 2. The Button (The thing you actually touch)
                Transform.translate(
                  offset: Offset(_dragOffset, 0),
                  // MOVED GESTURE DETECTOR HERE 👇
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        // Now 'delta' is exactly how much YOUR FINGER moved
                        double newPos = _dragOffset + details.delta.dx;
                        _dragOffset = newPos.clamp(0.0, maxDragDistance);
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_dragOffset > maxDragDistance * 0.7 || 
                          details.primaryVelocity! > 800) {
                        widget.onTransfer();
                        _resetSlide();
                      } else {
                        _resetSlide();
                      }
                    },
                    onHorizontalDragCancel: () {
                      _resetSlide();
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: widget.riskColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: widget.riskColor.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _dragOffset > (maxDragDistance * 0.9)
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
