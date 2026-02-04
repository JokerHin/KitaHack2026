import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> enqueuePatient(Map<String, dynamic> patient, double prob) async {
    await _db.collection('queue').add({
      'patient_data': patient,
      'ai_result': {'risk_probability': prob},
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePatient(String docId) async {
    try {
      await _db.collection('queue').doc(docId).delete();
    } catch (e) {
      print('Error deleting patient $docId: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> queueStream() => _db
      .collection('queue')
      .orderBy('ai_result.risk_probability', descending: true)
      .snapshots();
}
