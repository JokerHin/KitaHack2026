import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for AI-powered risk prediction using clinical heuristics
/// (TFLite integration intentionally disabled due to compatibility issues)
class ModelService {
  ModelService._();
  static final instance = ModelService._();

  bool _isModelLoaded = false;

  /// Initialize the prediction model (heuristic approach)
  Future<void> loadModel() async {
    if (_isModelLoaded) return;
    await Future.delayed(const Duration(milliseconds: 50));
    _isModelLoaded = true;
    print('✓ Clinical prediction model initialized (heuristic-based)');
  }

  /// Predict risk probability using clinical heuristics
  Future<double> predict(Map<String, double> features) async {
    await loadModel();
    // Try server-side inference first (local dev server). If the model
    // server is running (see model_server.py in repo root) we will POST
    // features to it. For Android emulator use 10.0.2.2; for real device
    // set your server address in `serverUrl`.
    const serverUrl = 'http://10.0.2.2:5000/predict';
    try {
      final body = json.encode({'features': features});
      final resp = await http
          .post(Uri.parse(serverUrl),
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final prob = (data['probability'] ?? data['prob'] ?? 0.0) as num;
        return prob.toDouble();
      }
    } catch (e) {
      // ignore and fallback to heuristic
    }

    return _predictWithHeuristic(features);
  }

  /// Clinical heuristic-based risk assessment (fallback)
  double _predictWithHeuristic(Map<String, double> features) {
    try {
      final oxygen = features['oxygen'] ?? 98.0;
      final heartRate = features['heart_rate'] ?? 80.0;
      final painScale = features['pain_scale'] ?? 0.0;
      final temperature = features['temperature'] ?? 37.0;
      final waitingTime = features['waiting_time'] ?? 0.0;

      double score = 0.0;

      if (oxygen < 85) {
        score += 0.35;
      } else if (oxygen < 90) {
        score += 0.25;
      } else if (oxygen < 94) {
        score += 0.10;
      }

      if (heartRate < 50 || heartRate > 130) {
        score += 0.25;
      } else if (heartRate < 60 || heartRate > 110) {
        score += 0.15;
      }

      score += (painScale / 10) * 0.20;

      if (temperature > 39 || temperature < 35.5) {
        score += 0.15;
      } else if (temperature > 38.5 || temperature < 36) {
        score += 0.08;
      }

      score += math.min(waitingTime / 120, 0.10);

      return math.min(score, 1.0);
    } catch (e) {
      print('Prediction error: $e');
      return 0.5;
    }
  }

  /// Get risk category from probability
  String getRiskCategory(double probability) {
    if (probability >= 0.75) return 'HIGH RISK';
    if (probability >= 0.40) return 'MODERATE RISK';
    return 'LOW RISK';
  }

  void dispose() {
    _isModelLoaded = false;
  }
}
