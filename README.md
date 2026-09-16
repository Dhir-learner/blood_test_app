# blood_test_app

A Flutter + Firebase app for at-home blood tests: patients book an appointment
and pick their address on a map, an admin assigns a phlebotomist who collects
the sample at home, and the admin uploads the lab report for the patient to
view in the app.

## Roles

| Role | What they can do |
| --- | --- |
| `patient` | Book appointments for themselves, see their own appointments and reports |
| `admin` | See all appointments, assign phlebotomists, upload reports |
| `phlebotomist` | See appointments assigned to them, mark them as collected |

Everyone who registers in the app becomes a **patient**. To make someone an
admin or phlebotomist, open **Firebase console → Firestore → `users/{uid}`**
and change the `role` field (an existing admin can also do this). Create the
first admin this way.

## Setup

1. Add your Firebase config files (they are git-ignored, never commit them):
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
2. `flutter pub get`
3. Deploy the security rules and indexes (requires the
   [Firebase CLI](https://firebase.google.com/docs/cli)):

   ```sh
   firebase deploy --only firestore:rules,firestore:indexes --project laboratory-app-2953e
   ```

   No billing account is needed. Re-run this whenever `firestore.rules` changes.
4. `flutter run`

## Security model

- `firestore.rules` is the real access control; the app's UI is not. Keep it
  deployed whenever the data model changes.
- Lab reports are stored as binary chunks in Firestore, under
  `appointments/{id}/reportChunks`, because Cloud Storage requires the paid
  Blaze plan. Only the appointment's patient and admins can read them — not the
  phlebotomist who collected the sample — and every read goes through the rules,
  so there is no shareable link. Reports are capped at 4 MB.
- If you later upgrade to Blaze, [storage.rules](storage.rules) has the Cloud
  Storage rules ready, with switch-over instructions at the top of the file.
