import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create Appointment
  Future<void> createAppointment({
    required String patientId,
    required String patientName,
    required String testType,
    required DateTime dateTime,
    required double latitude,
    required double longitude,
    required String address,
    required String flatNumber,
    required String floor,
  }) async {
    await _db.collection('appointments').add({
      'patientId': patientId,
      'patientName': patientName,
      'testType': testType,
      'dateTime': Timestamp.fromDate(dateTime),
      'location': GeoPoint(latitude, longitude),
      'address': address,
      'flatNumber': flatNumber,
      'floor': floor,
      'status': 'pending', // pending, assigned, completed
      'phlebotomistId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream of appointments for a patient
  Stream<QuerySnapshot> getPatientAppointments(String patientId) {
    return _db
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .orderBy('dateTime', descending: true)
        .snapshots();
  }
  
  // Stream of all pending appointments (for Admin)
  Stream<QuerySnapshot> getPendingAppointments() {
    return _db
        .collection('appointments')
        .where('status', isEqualTo: 'pending')
        .orderBy('dateTime')
        .snapshots();
  }
}
