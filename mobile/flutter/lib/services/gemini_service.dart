import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for generating AI explanations using Google AI Studio (Gemini)
class GeminiService {
  static final GeminiService instance = GeminiService._();
  GeminiService._();

  // Gemini API key from Google AI Studio
  static const String _apiKey = 'AIzaSyBcCH2-U8ftQm_nD3k6U7kTpc8VQU2S_lQ';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// Generate clinician-friendly explanation for AI risk prediction
  Future<String> generateExplanation({
    required Map<String, dynamic> patientData,
    required double riskProbability,
    required String riskCategory,
  }) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      // Fallback explanation if API key not configured
      return _generateFallbackExplanation(
          patientData, riskProbability, riskCategory);
    }

    try {
      final prompt = _buildPrompt(patientData, riskProbability, riskCategory);

      final response = await http
          .post(
            Uri.parse('$_baseUrl?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.7,
                'maxOutputTokens': 200,
              }
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return text ??
            _generateFallbackExplanation(
                patientData, riskProbability, riskCategory);
      } else {
        final errorMsg = response.statusCode == 429
            ? 'Gemini API quota exceeded (check https://aistudio.google.com/apikey)'
            : 'Gemini API error: ${response.statusCode}';
        print(errorMsg);
        return _generateFallbackExplanation(
            patientData, riskProbability, riskCategory);
      }
    } catch (e) {
      print('Gemini API exception: $e');
      return _generateFallbackExplanation(
          patientData, riskProbability, riskCategory);
    }
  }

  /// Simple chat reply based on current patient context and a free-text nurse message
  Future<String> generateChatReply({
    required Map<String, dynamic> patientData,
    required String userMessage,
  }) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      // Fallback: include patient summary and echo the question
      final summary = _generateFallbackExplanation(patientData, 0.0, 'SUMMARY');
      return 'Gemini unavailable. Patient summary: $summary\n\nNurse: $userMessage';
    }

    try {
      final prompt =
          '''You are a clinical assistant. Use the patient data below to answer the nurse's question concisely.

Patient Data: ${patientData}
Nurse Question: $userMessage

Answer in 1-3 sentences, focusing on actionable clinical guidance.''';

      final response = await http
          .post(
            Uri.parse('$_baseUrl?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.5,
                'maxOutputTokens': 200,
              }
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return text ?? 'No reply from Gemini.';
      } else {
        final errorMsg = response.statusCode == 429
            ? '⚠️ Gemini quota exceeded. Using clinical analysis instead.'
            : 'Gemini error ${response.statusCode}. Using clinical analysis.';
        return errorMsg;
      }
    } catch (e) {
      print('Gemini chat exception: $e');
      return 'Gemini unavailable (exception).';
    }
  }

  String _buildPrompt(Map<String, dynamic> data, double prob, String category) {
    return '''You are a clinical AI assistant. Explain this triage decision in 2-3 sentences for emergency department staff.

Patient Data:
- Age: ${data['age']?.toStringAsFixed(0)} years
- Heart Rate: ${data['heart_rate']?.toStringAsFixed(0)} bpm
- Oxygen Saturation: ${data['oxygen']?.toStringAsFixed(1)}%
- Temperature: ${data['temperature']?.toStringAsFixed(1)}°C
- Pain Scale: ${data['pain_scale']?.toStringAsFixed(0)}/10
- Waiting Time: ${data['waiting_time']?.toStringAsFixed(0)} minutes

AI Risk Assessment: $category (${(prob * 100).toStringAsFixed(1)}% probability)

Provide a concise clinical explanation focusing on the key vital signs that drove this risk classification. Be specific and actionable.''';
  }

  String _generateFallbackExplanation(
      Map<String, dynamic> data, double prob, String category) {
    final criticalFactors = <String>[];

    final oxygen = data['oxygen'] ?? 100;
    final heartRate = data['heart_rate'] ?? 70;
    final pain = data['pain_scale'] ?? 0;
    final temp = data['temperature'] ?? 37;

    if (oxygen < 90) {
      criticalFactors.add(
          'critically low oxygen saturation (${oxygen.toStringAsFixed(1)}%)');
    } else if (oxygen < 95) {
      criticalFactors
          .add('reduced oxygen saturation (${oxygen.toStringAsFixed(1)}%)');
    }

    if (heartRate > 120) {
      criticalFactors.add('tachycardia (${heartRate.toStringAsFixed(0)} bpm)');
    } else if (heartRate < 50) {
      criticalFactors.add('bradycardia (${heartRate.toStringAsFixed(0)} bpm)');
    }

    if (pain >= 8) {
      criticalFactors.add('severe pain (${pain.toStringAsFixed(0)}/10)');
    } else if (pain >= 5) {
      criticalFactors.add('moderate pain (${pain.toStringAsFixed(0)}/10)');
    }

    if (temp > 38.5) {
      criticalFactors.add('fever (${temp.toStringAsFixed(1)}°C)');
    } else if (temp < 36) {
      criticalFactors.add('hypothermia (${temp.toStringAsFixed(1)}°C)');
    }

    if (criticalFactors.isEmpty) {
      return 'Patient presents with stable vital signs. The $category risk classification is appropriate for routine triage workflow. Monitor for changes and reassess if symptoms develop.';
    } else {
      final factorsList = criticalFactors.join(', ');
      return 'The $category classification is driven by $factorsList. Immediate clinical assessment recommended to determine appropriate care pathway and interventions.';
    }
  }
}
