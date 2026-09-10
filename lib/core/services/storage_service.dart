import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadReport(String appointmentId, File file) async {
    try {
      final extension = p.extension(file.path);
      final ref = _storage.ref().child('reports/$appointmentId$extension');
      
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }
}
