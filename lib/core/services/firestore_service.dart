import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create User Profile. Self-registration always creates a patient;
  // admin/phlebotomist roles are granted by an admin (see README).
  Future<void> createUserProfile(
    String uid,
    String email,
    String name,
    String phone,
  ) async {
    await _db.collection('users').doc(uid).set({
      'email': email,
      'role': 'patient', // 'patient', 'admin', 'phlebotomist'
      'name': name,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get User Role
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc['role'] as String?;
      }
    } catch (e) {
      debugPrint("Error getting user role: $e");
    }
    return null;
  }

  // Get the whole profile, used when booking so the lab gets a real name and number.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      debugPrint("Error getting user profile: $e");
      return null;
    }
  }

  // Patients may correct their own name and phone number.
  //
  // Some accounts have no profile document at all — either they were created
  // before this app wrote one, or that write was rejected at the time. update()
  // fails on a missing document, so recreate it instead of leaving the patient
  // unable to save a phone number.
  Future<void> updateProfile(String uid, String name, String phone) async {
    final ref = _db.collection('users').doc(uid);
    final snapshot = await ref.get();

    if (snapshot.exists) {
      await ref.update({'name': name, 'phone': phone});
      return;
    }

    debugPrint("No profile document for $uid — creating one.");
    await ref.set({
      'email': FirebaseAuth.instance.currentUser?.email ?? '',
      'role': 'patient',
      'name': name,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
