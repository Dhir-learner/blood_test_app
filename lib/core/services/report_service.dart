import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

/// One lab report, belonging to a single booked test.
class LabReport {
  final String id; // the test's id
  final String testName;
  final String fileName;
  final String contentType;
  final int size;
  final int chunkCount;
  final DateTime? uploadedAt;

  const LabReport({
    required this.id,
    required this.testName,
    required this.fileName,
    required this.contentType,
    required this.size,
    required this.chunkCount,
    this.uploadedAt,
  });

  factory LabReport.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LabReport(
      id: doc.id,
      testName: data['testName'] as String? ?? 'Report',
      fileName: data['fileName'] as String? ?? 'report.pdf',
      contentType: data['contentType'] as String? ?? 'application/pdf',
      size: data['size'] as int? ?? 0,
      chunkCount: data['chunkCount'] as int? ?? 0,
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
    );
  }

  String get readableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Stores lab reports as binary chunks in Firestore, one report per booked test.
///
/// Cloud Storage needs a billing account, so reports live at
/// `appointments/{id}/reports/{testId}` with their bytes in a `chunks`
/// subcollection. firestore.rules lets only the patient and admins read them.
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

  DocumentReference<Map<String, dynamic>> _appointment(String appointmentId) =>
      _db.collection('appointments').doc(appointmentId);

  CollectionReference<Map<String, dynamic>> _reports(String appointmentId) =>
      _appointment(appointmentId).collection('reports');

  /// Live list of reports uploaded for an appointment.
  Stream<List<LabReport>> watchReports(String appointmentId) {
    return _reports(appointmentId).snapshots().map(
          (snap) => snap.docs.map(LabReport.fromDoc).toList(),
        );
  }

  /// Uploads [file] as the report for one booked test, replacing any previous one.
  Future<void> uploadReport({
    required String appointmentId,
    required String testId,
    required String testName,
    required PlatformFile file,
  }) async {
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

    final reportRef = _reports(appointmentId).doc(testId);
    final chunks = reportRef.collection('chunks');

    // Clear any earlier upload first, so a shorter report can't leave stale chunks.
    final existing = await chunks.get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }

    // Chunks are written one at a time to keep each request small; the metadata
    // document goes last so a half-finished upload is never shown to the patient.
    final chunkCount = (bytes.length / chunkSize).ceil();
    for (var i = 0; i < chunkCount; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < bytes.length) ? start + chunkSize : bytes.length;
      await chunks.doc('$i').set({
        'data': Blob(Uint8List.sublistView(bytes, start, end)),
      });
    }

    await reportRef.set({
      'testName': testName,
      'fileName': file.name,
      'contentType': contentType,
      'size': bytes.length,
      'chunkCount': chunkCount,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    // Denormalised so appointment lists can show "reports ready" without
    // reading the subcollection for every row.
    final all = await _reports(appointmentId).get();
    await _appointment(appointmentId).update({'reportCount': all.docs.length});
  }

  /// Reassembles one report. Throws if the rules deny access.
  Future<Uint8List> downloadReport({
    required String appointmentId,
    required String reportId,
    required int chunkCount,
  }) async {
    final chunks = _reports(appointmentId).doc(reportId).collection('chunks');
    final builder = BytesBuilder(copy: false);

    for (var i = 0; i < chunkCount; i++) {
      final doc = await chunks.doc('$i').get();
      final blob = doc.data()?['data'] as Blob?;
      if (blob == null) {
        throw 'This report is incomplete. Please ask the lab to upload it again.';
      }
      builder.add(blob.bytes);
    }

    return builder.toBytes();
  }

  /// Reports uploaded before per-test reports existed live on the appointment
  /// document itself. Used so older appointments still open.
  Future<Uint8List> downloadLegacyReport(String appointmentId, int chunkCount) async {
    final chunks = _appointment(appointmentId).collection('reportChunks');
    final builder = BytesBuilder(copy: false);

    for (var i = 0; i < chunkCount; i++) {
      final doc = await chunks.doc('$i').get();
      final blob = doc.data()?['data'] as Blob?;
      if (blob == null) {
        throw 'This report is incomplete. Please ask the lab to upload it again.';
      }
      builder.add(blob.bytes);
    }

    return builder.toBytes();
  }
}
