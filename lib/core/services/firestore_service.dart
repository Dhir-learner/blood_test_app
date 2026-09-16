import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create User Profile. Self-registration always creates a patient;
  // admin/phlebotomist roles are granted by an admin (see README).
  Future<void> createUserProfile(String uid, String email, String name) async {
    await _db.collection('users').doc(uid).set({
      'email': email,
      'role': 'patient', // 'patient', 'admin', 'phlebotomist'
      'name': name,
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

  // Get User Name
  Future<String?> getUserName(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final name = doc.data()?['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (e) {
      debugPrint("Error getting user name: $e");
    }
    return null;
  }
}
