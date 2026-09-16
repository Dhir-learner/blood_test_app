import 'package:cloud_firestore/cloud_firestore.dart';

/// An address the patient has saved so they don't retype it every booking.
class SavedAddress {
  final String id;
  final String label; // Home, Work, Mum's place…
  final String flatNumber;
  final String floor;
  final String address;
  final double latitude;
  final double longitude;
  final bool isDefault;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.flatNumber,
    required this.floor,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
  });

  factory SavedAddress.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final point = data['location'] as GeoPoint?;
    return SavedAddress(
      id: doc.id,
      label: data['label'] as String? ?? 'Address',
      flatNumber: data['flatNumber'] as String? ?? '',
      floor: data['floor'] as String? ?? '',
      address: data['address'] as String? ?? '',
      latitude: point?.latitude ?? 0,
      longitude: point?.longitude ?? 0,
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'flatNumber': flatNumber,
        'floor': floor,
        'address': address,
        'location': GeoPoint(latitude, longitude),
        'isDefault': isDefault,
      };

  /// "Flat 12A, Floor 3" — the part a collector needs to find the door.
  String get doorLine {
    final parts = [
      if (flatNumber.isNotEmpty) "Flat $flatNumber",
      if (floor.isNotEmpty) "Floor $floor",
    ];
    return parts.join(', ');
  }
}

/// Saved addresses live under the patient's own profile, so only they can see them.
class AddressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _db.collection('users').doc(uid).collection('addresses');

  Stream<List<SavedAddress>> watchAddresses(String uid) {
    return _collection(uid).snapshots().map(
          (snap) => snap.docs.map(SavedAddress.fromDoc).toList()
            ..sort((a, b) {
              if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
              return a.label.toLowerCase().compareTo(b.label.toLowerCase());
            }),
        );
  }

  Future<List<SavedAddress>> getAddresses(String uid) async {
    final snap = await _collection(uid).get();
    return snap.docs.map(SavedAddress.fromDoc).toList()
      ..sort((a, b) {
        if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
  }

  Future<void> addAddress(String uid, SavedAddress address) async {
    if (address.isDefault) await _clearDefault(uid);
    await _collection(uid).add({
      ...address.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAddress(String uid, SavedAddress address) async {
    if (address.isDefault) await _clearDefault(uid, except: address.id);
    await _collection(uid).doc(address.id).update(address.toMap());
  }

  Future<void> deleteAddress(String uid, String addressId) {
    return _collection(uid).doc(addressId).delete();
  }

  Future<void> setDefault(String uid, String addressId) async {
    await _clearDefault(uid, except: addressId);
    await _collection(uid).doc(addressId).update({'isDefault': true});
  }

  // Only one address can be the default one.
  Future<void> _clearDefault(String uid, {String? except}) async {
    final existing = await _collection(uid).where('isDefault', isEqualTo: true).get();
    for (final doc in existing.docs) {
      if (doc.id != except) {
        await doc.reference.update({'isDefault': false});
      }
    }
  }
}
