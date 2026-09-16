import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/test_catalog.dart';

class AppointmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Books one visit covering one or more tests.
  Future<void> createAppointment({
    required String patientId,
    required String patientName,
    required String patientPhone,
    required List<BloodTest> tests,
    required DateTime dateTime,
    required double latitude,
    required double longitude,
    required String address,
    required String flatNumber,
    required String floor,
    String? notes,
  }) async {
    final total = tests.fold<int>(0, (running, t) => running + t.priceInRupees);

    await _db.collection('appointments').add({
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'tests': tests.map((t) => t.toBooking()).toList(),
      // Kept as a readable summary so older screens and exports still work.
      'testType': tests.map((t) => t.name).join(', '),
      'price': total,
      'dateTime': Timestamp.fromDate(dateTime),
      'location': GeoPoint(latitude, longitude),
      'address': address,
      'flatNumber': flatNumber,
      'floor': floor,
      'notes': notes ?? '',
      'status': 'pending', // pending, assigned, completed, cancelled
      'phlebotomistId': null,
      'reportCount': 0,
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

  // A patient may call off a booking that hasn't been collected yet.
  Future<void> cancelAppointment(String appointmentId) {
    return _db
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': 'cancelled'});
  }
}
