import 'dart:math';

/// Service for generating realistic simulated patient data for demonstrations
class PatientSimulator {
  static final PatientSimulator instance = PatientSimulator._();
  PatientSimulator._();

  final Random _random = Random();

  /// Generate a complete simulated patient based on medical scenarios
  Map<String, dynamic> generatePatient({String? scenario}) {
    final selectedScenario = scenario ?? _randomScenario();

    switch (selectedScenario) {
      case 'chest_pain':
        return _generateChestPain();
      case 'trauma':
        return _generateTrauma();
      case 'respiratory':
        return _generateRespiratory();
      case 'stable':
        return _generateStable();
      default:
        return _generateRandom();
    }
  }

  String _randomScenario() {
    final scenarios = ['chest_pain', 'trauma', 'respiratory', 'stable'];
    return scenarios[_random.nextInt(scenarios.length)];
  }

  Map<String, dynamic> _generateChestPain() {
    final names = [
      'John Smith',
      'Sarah Johnson',
      'Michael Brown',
      'Emily Davis'
    ];
    return {
      'name': names[_random.nextInt(names.length)],
      'complaint': 'Chest Pain',
      'age': (50 + _random.nextInt(30)).toDouble(), // 50-80
      'heart_rate': (90 + _random.nextInt(50)).toDouble(), // 90-140
      'oxygen': (88 + _random.nextInt(10)).toDouble(), // 88-98
      'temperature': (36.5 + _random.nextDouble() * 2).toDouble(), // 36.5-38.5
      'pain_scale': (6 + _random.nextInt(5)).toDouble(), // 6-10
      'waiting_time': (10 + _random.nextInt(30)).toDouble(), // 10-40 mins
      'complaint_encoded': 2.0, // Chest pain
      'scenario': 'Chest Pain - High Risk',
    };
  }

  Map<String, dynamic> _generateTrauma() {
    final names = [
      'David Wilson',
      'Lisa Martinez',
      'James Taylor',
      'Jennifer Anderson'
    ];
    return {
      'name': names[_random.nextInt(names.length)],
      'complaint': 'Trauma / Injury',
      'age': (20 + _random.nextInt(50)).toDouble(), // 20-70
      'heart_rate': (100 + _random.nextInt(40)).toDouble(), // 100-140
      'oxygen': (85 + _random.nextInt(13)).toDouble(), // 85-98
      'temperature': (36.0 + _random.nextDouble() * 2.5).toDouble(),
      'pain_scale': (7 + _random.nextInt(4)).toDouble(), // 7-10
      'waiting_time': (5 + _random.nextInt(20)).toDouble(),
      'complaint_encoded': 1.0, // Trauma
      'scenario': 'Trauma - Urgent',
    };
  }

  Map<String, dynamic> _generateRespiratory() {
    final names = [
      'Robert Garcia',
      'Maria Rodriguez',
      'William Lee',
      'Patricia Moore'
    ];
    return {
      'name': names[_random.nextInt(names.length)],
      'complaint': 'Shortness of Breath',
      'age': (40 + _random.nextInt(40)).toDouble(), // 40-80
      'heart_rate': (85 + _random.nextInt(45)).toDouble(), // 85-130
      'oxygen': (82 + _random.nextInt(14)).toDouble(), // 82-96
      'temperature': (37.0 + _random.nextDouble() * 2.5).toDouble(),
      'pain_scale': (4 + _random.nextInt(5)).toDouble(), // 4-8
      'waiting_time': (15 + _random.nextInt(35)).toDouble(),
      'complaint_encoded': 3.0, // Respiratory
      'scenario': 'Respiratory Distress - Urgent',
    };
  }

  Map<String, dynamic> _generateStable() {
    final names = [
      'Christopher Thomas',
      'Jessica Jackson',
      'Daniel White',
      'Nancy Harris'
    ];
    return {
      'name': names[_random.nextInt(names.length)],
      'complaint': 'Minor Injury',
      'age': (30 + _random.nextInt(40)).toDouble(), // 30-70
      'heart_rate': (65 + _random.nextInt(25)).toDouble(), // 65-90
      'oxygen': (95 + _random.nextInt(6)).toDouble(), // 95-100
      'temperature':
          (36.5 + _random.nextDouble() * 1.0).toDouble(), // 36.5-37.5
      'pain_scale': (1 + _random.nextInt(4)).toDouble(), // 1-4
      'waiting_time': (20 + _random.nextInt(60)).toDouble(),
      'complaint_encoded': 0.0, // Minor
      'scenario': 'Stable Patient - Low Risk',
    };
  }

  Map<String, dynamic> _generateRandom() {
    final names = [
      'Alex Johnson',
      'Sam Smith',
      'Jordan Brown',
      'Casey Davis',
      'Taylor Wilson'
    ];
    final complaints = [
      'General Checkup',
      'Abdominal Pain',
      'Headache',
      'Fever',
      'Fatigue'
    ];
    return {
      'name': names[_random.nextInt(names.length)],
      'complaint': complaints[_random.nextInt(complaints.length)],
      'age': (18 + _random.nextInt(82)).toDouble(),
      'heart_rate': (50 + _random.nextInt(100)).toDouble(),
      'oxygen': (75 + _random.nextInt(26)).toDouble(),
      'temperature': (35.5 + _random.nextDouble() * 4.0).toDouble(),
      'pain_scale': _random.nextInt(11).toDouble(),
      'waiting_time': (5 + _random.nextInt(120)).toDouble(),
      'complaint_encoded': _random.nextInt(4).toDouble(),
      'scenario': 'Random Patient',
    };
  }

  /// Get list of available scenarios
  List<String> getScenarios() {
    return [
      'Random',
      'Chest Pain (High Risk)',
      'Trauma (Urgent)',
      'Respiratory Distress',
      'Stable Patient',
    ];
  }

  /// Map scenario display name to internal code
  String scenarioCode(String displayName) {
    switch (displayName) {
      case 'Chest Pain (High Risk)':
        return 'chest_pain';
      case 'Trauma (Urgent)':
        return 'trauma';
      case 'Respiratory Distress':
        return 'respiratory';
      case 'Stable Patient':
        return 'stable';
      default:
        return 'random';
    }
  }
}
