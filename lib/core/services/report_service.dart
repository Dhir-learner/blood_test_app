import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

/// Stores lab reports as binary chunks in Firestore.
///
/// Cloud Storage needs a billing account, so reports live in a `reportChunks`
/// subcollection of their appointment instead. Access is enforced by
/// firestore.rules: only the appointment's patient and admins can read them.
class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// A Firestore document can hold 1 MiB in total, so leave room for overhead.
  static const int chunkSize = 700 * 1024;

  /// Reports are capped well below the per-project storage quota.
  static const int maxReportBytes = 4 * 1024 * 1024;

  static const Map<String, String> _contentTypes = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
  };

  CollectionReference<Map<String, dynamic>> _chunks(String appointmentId) =>
      _db.collection('appointments').doc(appointmentId).collection('reportChunks');

  /// Uploads [file] as the report for [appointmentId], replacing any previous one.
  Future<void> uploadReport(String appointmentId, PlatformFile file) async {
    final extension = file.extension?.toLowerCase();
    final contentType = _contentTypes[extension];
    if (contentType == null) {
      throw 'Unsupported file type. Please pick a PDF, JPG or PNG.';
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw 'That file is empty.';
    if (bytes.length > maxReportBytes) {
      throw 'File is too large (max 4 MB).';
    }

    final chunks = _chunks(appointmentId);

    // Clear any earlier upload first, so a shorter report can't leave stale chunks behind.
    final existing = await chunks.get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }

    // Written one at a time to keep each request small; metadata goes last so a
    // half-finished upload is never shown to the patient.
    final chunkCount = (bytes.length / chunkSize).ceil();
    for (var i = 0; i < chunkCount; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < bytes.length) ? start + chunkSize : bytes.length;
      await chunks.doc('$i').set({
        'data': Blob(Uint8List.sublistView(bytes, start, end)),
      });
    }

    await _db.collection('appointments').doc(appointmentId).update({
      'reportName': file.name,
      'reportContentType': contentType,
      'reportSize': bytes.length,
      'reportChunkCount': chunkCount,
      'reportUploadedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reassembles the report for [appointmentId]. Throws if the rules deny access.
  Future<Uint8List> downloadReport(String appointmentId, int chunkCount) async {
    final chunks = _chunks(appointmentId);
    final builder = BytesBuilder(copy: false);

    for (var i = 0; i < chunkCount; i++) {
      final doc = await chunks.doc('$i').get();
      final blob = doc.data()?['data'] as Blob?;
      if (blob == null) throw 'This report is incomplete. Please ask the lab to upload it again.';
      builder.add(blob.bytes);
    }

    return builder.toBytes();
  }
}
