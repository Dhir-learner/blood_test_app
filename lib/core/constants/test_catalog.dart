/// The tests a patient can book.
///
/// Prices are placeholders — update them to match your lab's rate card.
/// Preparation notes are the common requirements; the lab should confirm them.
class BloodTest {
  /// Stable key. Used as the document id for this test's report, so it must
  /// not change once bookings exist.
  final String id;
  final String name;
  final String shortName;
  final String description;
  final bool fastingRequired;
  final int priceInRupees;
  final String reportTime;

  const BloodTest({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.fastingRequired,
    required this.priceInRupees,
    required this.reportTime,
  });

  /// The shape stored on an appointment's `tests` array.
  Map<String, dynamic> toBooking() => {
        'id': id,
        'name': name,
        'price': priceInRupees,
      };
}

const List<BloodTest> kBloodTests = [
  BloodTest(
    id: 'cbc',
    name: 'Complete Blood Count (CBC)',
    shortName: 'CBC',
    description: 'Screens for infection, anaemia and overall blood health.',
    fastingRequired: false,
    priceInRupees: 350,
    reportTime: 'Same day',
  ),
  BloodTest(
    id: 'lipid',
    name: 'Lipid Profile',
    shortName: 'Lipid',
    description: 'Cholesterol and triglycerides for heart health.',
    fastingRequired: true,
    priceInRupees: 600,
    reportTime: 'Same day',
  ),
  BloodTest(
    id: 'fbs',
    name: 'Blood Sugar (Fasting)',
    shortName: 'FBS',
    description: 'Fasting glucose level, used to screen for diabetes.',
    fastingRequired: true,
    priceInRupees: 150,
    reportTime: 'Same day',
  ),
  BloodTest(
    id: 'hba1c',
    name: 'HbA1c',
    shortName: 'HbA1c',
    description: 'Average blood sugar over the past three months.',
    fastingRequired: false,
    priceInRupees: 500,
    reportTime: '24 hours',
  ),
  BloodTest(
    id: 'thyroid',
    name: 'Thyroid Profile (T3, T4, TSH)',
    shortName: 'Thyroid',
    description: 'Checks thyroid function and hormone levels.',
    fastingRequired: false,
    priceInRupees: 550,
    reportTime: '24 hours',
  ),
  BloodTest(
    id: 'lft',
    name: 'Liver Function Test',
    shortName: 'LFT',
    description: 'Enzymes and proteins that show how the liver is working.',
    fastingRequired: true,
    priceInRupees: 700,
    reportTime: '24 hours',
  ),
  BloodTest(
    id: 'kft',
    name: 'Kidney Function Test',
    shortName: 'KFT',
    description: 'Creatinine, urea and electrolytes for kidney health.',
    fastingRequired: true,
    priceInRupees: 700,
    reportTime: '24 hours',
  ),
  BloodTest(
    id: 'vitd',
    name: 'Vitamin D (25-OH)',
    shortName: 'Vit D',
    description: 'Detects vitamin D deficiency affecting bones and immunity.',
    fastingRequired: false,
    priceInRupees: 1200,
    reportTime: '48 hours',
  ),
  BloodTest(
    id: 'vitb12',
    name: 'Vitamin B12',
    shortName: 'Vit B12',
    description: 'Checks for B12 deficiency causing fatigue and nerve issues.',
    fastingRequired: false,
    priceInRupees: 900,
    reportTime: '48 hours',
  ),
  BloodTest(
    id: 'fullbody',
    name: 'Complete Health Checkup',
    shortName: 'Full Body',
    description: 'A bundle covering blood, sugar, lipids, liver and kidneys.',
    fastingRequired: true,
    priceInRupees: 1999,
    reportTime: '48 hours',
  ),
];

BloodTest? findTestById(String? id) {
  if (id == null) return null;
  for (final test in kBloodTests) {
    if (test.id == id) return test;
  }
  return null;
}

BloodTest? findTestByName(String? name) {
  if (name == null) return null;
  for (final test in kBloodTests) {
    if (test.name == name) return test;
  }
  return null;
}

/// Reads the `tests` array off an appointment, falling back to the single
/// `testType` string used by bookings made before multi-test support.
List<Map<String, dynamic>> bookedTestsOf(Map<String, dynamic> appointment) {
  final raw = appointment['tests'];
  if (raw is List && raw.isNotEmpty) {
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  final legacyName = appointment['testType'] as String?;
  if (legacyName == null) return const [];
  final known = findTestByName(legacyName);
  return [
    {
      'id': known?.id ?? 'legacy',
      'name': legacyName,
      'price': appointment['price'] ?? known?.priceInRupees ?? 0,
    }
  ];
}

/// "CBC" or "CBC +2 more" — for list rows where space is tight.
String testSummary(Map<String, dynamic> appointment) {
  final tests = bookedTestsOf(appointment);
  if (tests.isEmpty) return 'Blood Test';
  final first = tests.first['name'] as String? ?? 'Blood Test';
  if (tests.length == 1) return first;
  return "$first  +${tests.length - 1} more";
}
