import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create User Profile
  Future<void> createUserProfile(String uid, String email, String role, String name) async {
    await _db.collection('users').doc(uid).set({
      'email': email,
      'role': role, // 'patient', 'admin', 'phlebotomist'
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
}
