# HomeLab — blood tests collected at home

A Flutter + Firebase app. Patients book blood tests from home, a phlebotomist
collects the sample at their door, and the lab uploads reports the patient
reads in the app.

**Firebase project:** `laboratory-app-2953e` ·
[Console](https://console.firebase.google.com/project/laboratory-app-2953e/overview)

---

## 1. Running the app

```powershell
cd "C:\Users\dhirt\.gemini\antigravity\scratch\blood_test_app"
flutter run
```

Start the emulator first (Android Studio → Device Manager → ▶) or plug in a
phone with USB debugging on.

While `flutter run` is attached: **r** = hot reload, **R** = restart, **q** = quit.

---

## 2. Adding users — read this first

**Everyone who registers in the app becomes a patient.** There is no role
picker, on purpose: if there were, anyone could sign up as an admin and read
every patient's medical data.

Admin and phlebotomist accounts are made in two steps: register normally in
the app, then change that account's role in the Firebase console.

### 2a. Add a patient

Nothing to do. They tap **Create an account** in the app and fill in name,
phone, email and password. Done.

### 2b. Add an admin or a phlebotomist

1. **Register the account in the app** like any patient — use a real email and
   password you'll remember, e.g. `collector2@yourlab.com`.

2. **Find its User UID:**
   [Console → Authentication → Users](https://console.firebase.google.com/project/laboratory-app-2953e/authentication/users).
   Find the email, copy the **User UID** (a long string like
   `gm6K17UEgzVa0aEXIywWOnWsRLX2`).

3. **Change the role:**
   [Console → Firestore → Data](https://console.firebase.google.com/project/laboratory-app-2953e/firestore/data/~2Fusers)
   → open the **`users`** collection → click the document whose ID matches
   that UID → click the **`role`** field → change the value → **Update**.

   | Role value | Gives them |
   | --- | --- |
   | `patient` | Book tests, see own appointments and reports |
   | `phlebotomist` | See jobs assigned to them, directions, mark collected |
   | `admin` | See all appointments, assign collectors, upload reports |

   Type the value exactly — lowercase, no spaces.

4. **Sign out and back in** in the app. The app picks the role up at sign-in,
   so it won't change while they stay logged in.

> **If the user document isn't in the `users` list:** open the app as that
> account, go to **Profile** (person icon, top right), fill in name and mobile
> number, and tap **Save details**. That creates the document. Then do step 3.

---

## 3. Things that will bite you later

### Rules must be deployed after any change

If you (or anyone) edit `firestore.rules`, the live app does **not** get them
until you run:

```powershell
cd "C:\Users\dhirt\.gemini\antigravity\scratch\blood_test_app"
firebase deploy --only firestore:rules --project laboratory-app-2953e
```

Symptom when you forget: things fail with **"permission denied"** or a vague
"Could not save / Could not book".

### "Permission denied" checklist

1. Did you deploy the rules (above)?
2. Is the user signed in?
3. Is the user's `role` what you think it is?
4. Does the user's document exist in `users` at all? (See the note in §2.)

### Reports are stored in the database, not Cloud Storage

Firebase now requires the paid **Blaze** plan for Cloud Storage, so reports are
stored as chunks inside Firestore instead.

- **Max 4 MB per report.** Bigger files are rejected with a clear message.
- Allowed: **PDF, JPG, PNG**.
- The free database quota is 1 GB total, so a few hundred reports is fine —
  thousands is not. If you outgrow it, upgrade to Blaze and switch to Cloud
  Storage; the rules for that are already written in `storage.rules` with
  instructions at the top.

### One report per test

A booking can contain several tests. The lab uploads a **separate report for
each**. In the admin dashboard, the upload dialog lists the booked tests and
you pick which one the file belongs to. Tests already uploaded show a green
tick; picking one again replaces its report.

### Prices are made up

The test catalogue lives in
[lib/core/constants/test_catalog.dart](lib/core/constants/test_catalog.dart).
The ten tests, their descriptions, fasting requirements and **prices** are
placeholders. Edit that file to match your real rate card.

Each test has an `id` (like `cbc`). **Don't change an `id` once bookings
exist** — reports are filed under it.

The fasting guidance is the standard advice; have your lab confirm the wording
before real patients rely on it.

### Indexes

The patient list needs a composite index, already defined in
`firestore.indexes.json`. If you ever see *"the query requires an index"*, run:

```powershell
firebase deploy --only firestore:indexes --project laboratory-app-2953e
```

Then wait a few minutes — indexes build in the background.

---

## 4. How the app flows

```
Patient books  →  Admin assigns a collector  →  Collector marks collected
                                                        ↓
Patient reads report  ←  Admin uploads a report per test
```

- A patient can **cancel** while the status is Pending or Assigned, not after.
- The collector gets **Google Maps directions** and a **call patient** button
  (which uses the phone number from the patient's profile — so an empty phone
  number means no call button value).
- Saved addresses let a patient book without retyping. They're private: even
  admins can't read a patient's address book. Only the copy attached to a
  booking is visible to the lab.

---

## 5. Who can see what

Enforced by `firestore.rules`, not by the UI. 49 automated scenarios cover it.

| | Own data | Other patients | Reports |
| --- | --- | --- | --- |
| Patient | Read + edit | No | Own only |
| Phlebotomist | Assigned jobs only | Only their assigned jobs | **No** |
| Admin | Everything | Yes | Yes |

Deliberate: **the phlebotomist cannot read lab reports.** They collect the
sample; they have no reason to read results.

---

## 6. Setup on a fresh machine

1. Put the Firebase config files in place (they are git-ignored, never commit
   them):
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
2. `flutter pub get`
3. Deploy rules and indexes:
   ```powershell
   firebase deploy --only firestore:rules,firestore:indexes --project laboratory-app-2953e
   ```
4. `flutter run`

### This machine's quirks (they cost hours to rediscover)

- **Java:** Flutter is pointed at JDK 21 at
  `C:\Program Files\Android\openjdk\jdk-21.0.8`. The `Android Studio` folder in
  Program Files is broken (the real install is `Android Studio1`) and its Java
  is too new for this Gradle. Undo with `flutter config --jdk-dir=`.
- **Emulator:** the AVD is `Medium_Phone_API_36.1`. A debug APK is ~200 MB, so
  installs fail with `INSUFFICIENT_STORAGE` once the device fills up. Wipe it:
  Device Manager → ▾ → **Wipe Data**.
- **Emulator GPS:** set a location in the emulator's **⋯ → Location** panel,
  or the map screen waits 10 seconds and falls back to a default. Real phones
  are fine.
- **adb** lives at
  `C:\Users\dhirt\AppData\Local\Android\sdk\platform-tools\adb.exe`.

---

## 7. Before real patients use this

- [ ] **Change the app ID** from `com.example.blood_test_app` in
      `android/app/build.gradle.kts`.
- [ ] **Create a release keystore.** Release builds are currently signed with
      the debug key, which the Play Store will reject.
- [ ] **Replace the placeholder prices** and confirm the fasting text.
- [ ] Decide on Blaze + Cloud Storage if report volume will grow.
- [ ] Consider what regulations apply to you: this stores names, phone numbers,
      home addresses, GPS coordinates and medical reports.

---

## 8. Useful commands

```powershell
flutter run                     # run on the connected device
flutter analyze                 # check for code errors
flutter test                    # run unit tests
flutter build apk --debug       # build an installable APK
flutter clean                   # fix weird stale-build errors

firebase deploy --only firestore:rules --project laboratory-app-2953e
firebase deploy --only firestore:indexes --project laboratory-app-2953e
```

APK output: `build\app\outputs\flutter-apk\app-debug.apk`

---

## 9. Where things live

| Path | What |
| --- | --- |
| `lib/core/constants/test_catalog.dart` | The tests, prices, fasting rules |
| `lib/core/services/` | Firebase access (auth, appointments, reports, addresses) |
| `lib/core/theme/app_theme.dart` | Colours, light/dark theme |
| `lib/features/patient/` | Patient screens |
| `lib/features/admin/` | Lab dashboard |
| `lib/features/phlebotomist/` | Collector screens |
| `firestore.rules` | **The real access control** |
| `storage.rules` | Unused — only if you move to Cloud Storage |
| `CHANGES.md` | What was fixed and why, in detail |
