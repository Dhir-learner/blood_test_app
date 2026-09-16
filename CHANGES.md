# Code Review & Security Fixes — 2026-09-10

This document explains every change made during the project review: what was
wrong, why it mattered, and what was done about it.

## Summary

| Area | Before | After |
| --- | --- | --- |
| `flutter analyze` | 3 errors, 5 warnings/infos — **app did not compile** | No issues found |
| `flutter test` | Default counter test (would fail) | Passing test for this app |
| Security rules | None in the repo | Firestore + Storage rules, 33/33 emulator tests passing |
| Role security | Anyone could register as **admin** | Registration always creates a patient |
| Report privacy | Public, permanent download link stored in the database | Stored inside Firestore; every read checked by the rules |

---

## 1. Security fixes

### 1.1 Anyone could make themselves an admin (critical)

**Problem:** The registration screen had a "Role" dropdown with *Patient /
Admin / Phlebotomist*. Anyone could create an **admin** account and see every
patient's name, address, location and lab reports.

**Fix:**
- Removed the role dropdown from [login_screen.dart](lib/features/auth/login_screen.dart).
- `FirestoreService.createUserProfile()` now always writes `role: 'patient'`
  and no longer takes a role parameter ([firestore_service.dart](lib/core/services/firestore_service.dart)).
- `firestore.rules` rejects any self-created profile whose role isn't
  `patient`, and stops users from changing their own role later. Without this
  rule, an attacker could skip the app and write directly to the database.

**How to create admins/phlebotomists now:** register normally, then change the
`role` field on `users/{uid}` in the Firebase console. This is documented in
the README.

### 1.2 No database security rules (critical)

**Problem:** The repo had no `firestore.rules` or `storage.rules`. Access
control only existed in the app's UI, and an attacker can bypass the UI by
calling Firebase directly. Depending on how the Firebase project was set up,
the database was either open to everyone ("test mode") or completely locked.

**Fix:** Added these files:

| File | Purpose |
| --- | --- |
| [firestore.rules](firestore.rules) | Who can read/write users and appointments |
| [storage.rules](storage.rules) | Unused — only needed if you upgrade to Blaze and move reports to Cloud Storage |
| [firestore.indexes.json](firestore.indexes.json) | Composite indexes the app's queries need |
| [firebase.json](firebase.json) | Firebase CLI config tying the above together |

**What the rules enforce:**

- **Users:** you can read your own profile; admins can read all profiles.
  You can change your own `name` but never your `role` or `email`.
- **Appointments:**
  - Patients can only book for themselves. New bookings must be `pending`,
    unassigned, in the future, and have no extra fields such as a smuggled
    `reportPath`. Text fields have length limits.
  - Patients see only their own appointments.
  - Phlebotomists see only appointments assigned to them, and the only change
    they can make is `assigned → completed`.
  - Admins can see everything, assign phlebotomists, and attach reports.
- **Reports (`reportChunks`):** only admins can upload. Only the appointment's
  patient and admins can read. Phlebotomists, other patients and signed-out
  users can't.

**Verified:** 34 allow/deny scenarios were run against the Firestore emulator
and all passed. They cover each role, cross-patient access, privilege
escalation, unauthenticated access, and report upload/read permissions.

### 1.3 Lab reports were available to anyone with the link (high)

**Problem:** After upload, the app saved a Firebase **download URL** in the
appointment document. Those URLs carry a permanent access token and skip
security rules completely. Anyone who got the link could open the medical
report forever. The assigned phlebotomist could also read the appointment
document, so they could see the link too.

**Fix:** No download URL is stored anywhere. Reports now live inside Firestore
itself, as binary chunks in a `reportChunks` subcollection of their appointment
([report_service.dart](lib/core/services/report_service.dart)). Every read is
checked against the security rules, so a link can't be forwarded to anyone.

- The admin uploads a PDF/JPG/PNG (max 4 MB), which is split into ~700 KB
  chunks because a Firestore document can hold at most 1 MiB.
- The appointment records only metadata: `reportChunkCount`, `reportName`,
  `reportContentType`, `reportSize`, `reportUploadedAt`.
- When the patient opens a report, the app reads the chunks, reassembles the
  file into the app's **private cache**, and opens it in the device's viewer
  ([report_view_screen.dart](lib/features/patient/report_view_screen.dart)).
  The previous report is deleted from the cache each time, so copies don't
  accumulate on the phone.
- The rules let only the appointment's patient and admins read the chunks, and
  only admins write them. **The phlebotomist who collected the sample cannot
  read the report.**

**Why not Cloud Storage?** Firebase now requires the paid Blaze plan for Cloud
Storage. The rules for that approach are kept in [storage.rules](storage.rules)
with instructions at the top, in case you upgrade later.

> **Note:** Reports uploaded before this change used a `reportUrl` field and
> won't appear in the app. Re-upload them from the admin dashboard.

### 1.4 URL injection in address search (medium)

**Problem:** The map search put user input straight into the Nominatim URL
(`...&q=$query`). Typing `&`, `#` or `=` could break the request or add extra
query parameters.

**Fix:** Requests are now built with `Uri.https(...)`, which encodes every
parameter ([map_picker_screen.dart](lib/features/patient/map_picker_screen.dart)).

### 1.5 Error messages leaked internals (low)

**Problem:** Screens showed raw exception text, such as Firebase error codes
and stack details, in snackbars.

**Fix:**
- Login and registration now show friendly messages. Wrong email and wrong
  password both show *"Invalid email or password"*, so the screen doesn't
  reveal which accounts exist.
- Other screens show a generic message and log the details with `debugPrint`,
  which is stripped from release builds.

### 1.6 Passwords were silently trimmed (low)

**Problem:** The login screen called `.trim()` on passwords, so a password
with a leading or trailing space was quietly changed.

**Fix:** Passwords are now sent exactly as typed.

### 1.7 Android hardening

- Added `android:allowBackup="false"` to
  [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml). Without it,
  cached medical data and login tokens could be copied off the device through
  Android backups.
- Removed an unused Google Maps `API_KEY` placeholder (the app uses
  OpenStreetMap). The placeholder invited someone to paste a real key into a
  file that gets committed.

---

## 2. Compile errors fixed

| File | Error | Fix |
| --- | --- | --- |
| [patient_home.dart](lib/features/patient/patient_home.dart) | `ReportViewScreen` isn't defined | Added the missing import |
| [admin_home.dart](lib/features/admin/admin_home.dart) | `FilePicker.platform` doesn't exist | Updated to the file_picker v12 API (`FilePicker.pickFile()`) |
| [admin_home.dart](lib/features/admin/admin_home.dart) | Undefined name `p` (`p.basename`) | Uses `PlatformFile.name` instead |

Report upload now reads the file bytes (`putData`) instead of using a local
`File` path. This works with Android's content URIs, where the old
path-based approach would return `null`.

---

## 3. Runtime bugs fixed

| Where | Bug | Fix |
| --- | --- | --- |
| Patient, Admin, Phlebotomist lists | Any Firestore error, like a missing index or permission denied, showed as *"No appointments yet"*, hiding real problems | Added `snapshot.hasError` handling with an error message |
| Map picker | `_mapController.move()` ran before the map had rendered. It threw, and the initial address lookup never ran | Moves only after `onMapReady`; before that the map opens at the right spot through `initialCenter` |
| Map picker | If getting the location failed, the loading spinner stayed forever | Wrapped in `try/finally` so loading always ends |
| Map picker | `setState` after async calls could crash if the user left the screen | Added `mounted` checks |
| Report viewer | `canLaunchUrl` returns `false` on Android 11+ unless the manifest declares `<queries>`, so reports never opened | Calls `launchUrl` directly and checks its result |
| Booking | You could book a time earlier today that had already passed | Rejects times that aren't in the future. The rules enforce this too |
| Booking | The appointment used the patient's **email** as their name | Uses the name from the patient's profile, falling back to email |
| Phlebotomist | "Mark as completed" had no error handling | Shows an error if the update fails |
| Admin | "Assign" had no error handling, and a `BuildContext` lint warning | Added `try/catch` and a `context.mounted` check |
| Login | Text controllers were never disposed (memory leak) | Added `dispose()` |
| Login | You could register with an empty name | Validates that all fields are filled |

---

## 4. Platform configuration

| File | Change | Why |
| --- | --- | --- |
| [ios/Runner/Info.plist](ios/Runner/Info.plist) | Added `NSLocationWhenInUseUsageDescription` | iOS refuses location access without it, so "use my location" would fail |
| [project.pbxproj](ios/Runner.xcodeproj/project.pbxproj), [AppFrameworkInfo.plist](ios/Flutter/AppFrameworkInfo.plist) | iOS deployment target 13.0 → **15.0** | `firebase_core` and `cloud_firestore` require iOS 15, so the iOS build would fail during CocoaPods install |

---

## 5. Repository cleanup

- **Removed from git:** `analysis_final.txt`, `analysis_report.txt` (old
  analyzer dumps that no longer match the code) and
  `android/build/reports/problems/problems-report.html` (a Gradle build output).
- **Added to `.gitignore`:** `/android/build/`, `analysis*.txt`, `.firebase/`,
  `*-debug.log`.
- **Confirmed:** `google-services.json`, `GoogleService-Info.plist` and
  `firebase_options.dart` were **never committed** to git history.

## 6. Tests & docs

- [test/widget_test.dart](test/widget_test.dart): replaced Flutter's default
  counter test, which tested a counter this app doesn't have, with a test of
  the Firebase-initialization error screen.
- [README.md](README.md): replaced the Flutter template with what the app does,
  the three roles, how to create admins, setup steps, and how to deploy the
  rules.

---

## 7. What you need to do

1. **Deploy the rules. Until you do, none of the database-level security fixes
   are active:**
   ```sh
   npm install -g firebase-tools
   firebase login
   firebase deploy --only firestore:rules,firestore:indexes --project laboratory-app-2953e
   ```
   No Blaze plan or billing account is needed for this.
2. **Check existing accounts.** Anyone who registered as `admin` or
   `phlebotomist` through the old dropdown still has that role. Check the
   `users` collection in the Firebase console and fix any roles that shouldn't
   be there.
3. **Re-upload existing reports** (see note in 1.3).
4. **Nothing — the Android build is fixed and verified.** See section 9 for
   what changed on your machine.

## 8. Known remaining issues (not changed)

- **Release builds are signed with the debug key**
  ([build.gradle.kts](android/app/build.gradle.kts)). Set up a real release
  keystore before publishing to the Play Store.
- **Reports are limited to 4 MB each** because they live in Firestore
  documents, and they consume the 1 GiB free database quota. If reports get
  large or numerous, upgrade to Blaze and move them to Cloud Storage using
  [storage.rules](storage.rules).
- **Opened reports are handed to the device's PDF viewer**, so the file briefly
  exists in the app's cache. It's deleted the next time a report is opened.
- **The application ID is still `com.example.blood_test_app`.** Change it
  before publishing.
- **Firebase roles use Firestore lookups inside the rules.** This works
  correctly, but moving roles to Firebase Auth custom claims (set by a Cloud
  Function) would cost fewer reads at scale.

## 9. Changes made outside the project (your machine)

The Android build was failing for reasons unrelated to the code. Fixing it
required two changes outside this repo:

1. **Flutter's JDK setting (global, affects all your Flutter projects).**
   Flutter was auto-detecting a broken Android Studio folder at
   `C:\Program Files\Android\Android Studio`; the real install is
   `Android Studio1`, and its bundled JDK is Java 25, which this Gradle
   version can't parse. Flutter now points at JDK 21:
   ```sh
   flutter config --jdk-dir "C:\Program Files\Android\openjdk\jdk-21.0.8"
   ```
   To undo: `flutter config --jdk-dir=` (empty value). Note that Android
   Studio was open during this change; restart it so it picks up the setting.

2. **Ran `flutter clean`.** Several generated files were stale, left over from
   before the `file_picker` v12 upgrade. `GeneratedPluginRegistrant.java` still
   referenced plugins that no longer exist, which broke compilation with
   *"cannot find symbol: PackageInfoPlugin"*. These files are generated and
   git-ignored, so Flutter rebuilt them correctly. This also deleted the
   `build/` folder, including an old APK from a previous build.

The corrupted Gradle cache entry that failed earlier with *"Could not move
temporary workspace"* resolved itself once the stale Gradle daemon was stopped,
so nothing in `C:\Users\dhirt\.gradle` was deleted.

## Verification

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues found |
| `flutter test` | All tests passed |
| Security rules (Firestore emulator, 34 scenarios) | 34/34 passed |
| Android debug build | `flutter build apk --debug` succeeded |
| iOS build | Not verified; needs a Mac |
