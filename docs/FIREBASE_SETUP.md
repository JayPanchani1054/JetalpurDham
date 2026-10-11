# Firebase setup — step by step

This guide takes you from nothing to a published Jetalpur Dham app. Follow the
steps in order; each one says exactly what to click or type. It is written for
someone who has not used Firebase before. Allow about two hours the first time,
mostly waiting for Google and Apple.

> **What you end up with:** one Firebase project that holds all app content
> (Firestore), all files (Storage), push notifications (Cloud Messaging) and
> the automatic helpers (Cloud Functions). Temple staff then manage everything
> from the Firebase console — see [ADMIN_GUIDE.md](ADMIN_GUIDE.md). There is
> no separate admin panel to host.

**Contents**

1. [What you need](#1-what-you-need)
2. [Create the Firebase project](#2-create-the-firebase-project)
3. [Switch to the Blaze plan](#3-switch-to-the-blaze-plan-pay-as-you-go)
4. [Create Firestore](#4-create-the-firestore-database)
5. [Create Storage](#5-create-cloud-storage)
6. [Connect the app (`flutterfire configure`)](#6-connect-the-app-to-firebase-flutterfire-configure)
7. [iOS push notifications (APNs key)](#7-ios-push-notifications-apns-key)
8. [Google Maps keys](#8-google-maps-api-keys)
9. [Deploy rules, indexes and Cloud Functions](#9-deploy-rules-indexes-and-cloud-functions)
10. [Load the starter content (seed)](#10-load-the-starter-content-seed)
11. [Optional: photo thumbnails (Resize Images)](#11-optional-photo-thumbnails-resize-images-extension)
12. [Optional: donation e-mails (Trigger Email)](#12-optional-donation-e-mails-trigger-email-extension)
13. [Test a push notification](#13-test-a-push-notification)
14. [Android release signing](#14-android-release-signing)
15. [Build and publish](#15-build-and-publish)
16. [Troubleshooting](#16-troubleshooting)

---

## 1. What you need

| Item | Why |
|---|---|
| A Google account owned by the temple (e.g. a trust Gmail) | Owns the Firebase project. Add other staff later as members. |
| A payment card | The Blaze plan needs one (costs stay near zero — see step 3). |
| A computer with [Flutter 3.47](https://docs.flutter.dev/get-started/install), [Node.js 22](https://nodejs.org) and Git | To configure, build and deploy. |
| Firebase CLI | `npm install -g firebase-tools` then `firebase login` |
| FlutterFire CLI | `dart pub global activate flutterfire_cli` |
| For iOS: a Mac with Xcode and an [Apple Developer account](https://developer.apple.com/programs/) | Building the iPhone app and push notifications. |
| For Android: a [Google Play Console](https://play.google.com/console) account | Publishing to the Play Store. |

Check your tools:

```bash
flutter --version      # 3.47.x
node --version         # v22.x
firebase --version
flutterfire --version
```

## 2. Create the Firebase project

1. Open <https://console.firebase.google.com> and sign in with the temple account.
2. Click **Create a project** (or **Add project**).
3. Name: `Jetalpur Dham`. Firebase suggests a **project id** such as
   `jetalpur-dham` (you can edit it once, now). **Write the project id down** —
   you will type it several times.
4. Google Analytics: keep it **enabled** (the app uses it for anonymous usage
   statistics) and pick or create an Analytics account. Click **Create project**.

## 3. Switch to the Blaze plan (pay-as-you-go)

Cloud Functions (automatic kirtan/photo/PDF documents and push notifications)
and Cloud Storage both require the Blaze plan.

1. In the console, bottom-left, click **Upgrade** (or ⚙ **Project settings → Usage and billing**).
2. Choose **Blaze**, add the payment card and confirm.
3. **Set a budget alert** so there are never surprises: open
   <https://console.cloud.google.com/billing> → your billing account →
   **Budgets & alerts → Create budget**, e.g. ₹1,000 per month with e-mail
   alerts at 50 %, 90 % and 100 %.

> **What will it cost?** For a temple app the database, functions and push
> notifications normally stay inside Google's free allowances. The main cost is
> **downloads from Storage** (devotees streaming kirtans and opening photos
> and PDFs), billed at normal Google Cloud Storage rates for a Mumbai bucket —
> typically a few rupees per GB. Keeping kirtans at 96–128 kbps MP3 and photos
> at ~2048 px (as the admin guide recommends) keeps this small, and the app
> caches everything it has downloaded. Check
> <https://firebase.google.com/pricing> for current prices.

## 4. Create the Firestore database

1. Left menu: **Build → Firestore Database → Create database**.
2. Database ID: keep **(default)**. Edition: **Standard**.
3. **Location: `asia-south1 (Mumbai)`**. ⚠ This cannot be changed later, and the
   Cloud Functions are set up for Mumbai (`REGION` in `functions/src/config.ts`).
4. Start in **production mode** (everything locked). Our real rules are
   deployed in step 9. Click **Create**.

## 5. Create Cloud Storage

1. Left menu: **Build → Storage → Get started**.
2. **Location: `asia-south1 (Mumbai)`** — the same as Firestore. Storage
   functions must run in the same location as the bucket.
3. Start in **production mode**. Click **Done**.
4. Note the bucket name shown at the top, e.g. `jetalpur-dham.firebasestorage.app`.

## 6. Connect the app to Firebase (`flutterfire configure`)

From the project folder (the one containing `pubspec.yaml`):

```bash
flutterfire configure \
  --project=<your-project-id> \
  --platforms=android,ios \
  --android-package-name=com.jetalpurdham.app \
  --ios-bundle-id=com.jetalpurdham.app
```

(On Windows PowerShell write it on one line without the `\`.)

This registers the Android and iOS apps in Firebase and writes:

* `lib/firebase_options.dart` — replaces the placeholder in the repository,
* `android/app/google-services.json`,
* `ios/Runner/GoogleService-Info.plist`,

and adds the Google Services / Crashlytics Gradle plugins when needed. Answer
**yes** if it asks to update Gradle files. Commit these files — they are
identifiers, not secrets (security comes from the rules in step 9).

**Android SHA fingerprints** (needed later for Google Maps key restrictions
and for any future Google sign-in):

```bash
cd android && ./gradlew signingReport     # Windows: gradlew signingReport
```

Copy the **SHA-1** of the `debug` variant (and later of your release/upload key
and of Play App Signing, see step 15) into
**Firebase console → ⚙ Project settings → Your apps → Android app → Add fingerprint**.

## 7. iOS push notifications (APNs key)

Apple delivers iPhone notifications, so Firebase needs an Apple key once.

1. <https://developer.apple.com/account> → **Certificates, Identifiers & Profiles**.
2. **Identifiers → +** → App IDs → App → Bundle ID (explicit)
   `com.jetalpurdham.app`, description `Jetalpur Dham`; tick **Push Notifications** → Register.
   (Skip if Xcode already created it.)
3. **Keys → +** → name `Jetalpur Dham APNs`, tick **Apple Push Notifications
   service (APNs)** → Continue → Register → **Download** the `.p8` file (you can
   download it only once — store it safely). Note the **Key ID** and your
   **Team ID** (top-right of the developer site).
4. Firebase console → ⚙ **Project settings → Cloud Messaging → Apple app
   configuration → APNs Authentication Key → Upload**: choose the `.p8`, enter
   Key ID and Team ID.
5. In Xcode open `ios/Runner.xcworkspace` → target **Runner** →
   **Signing & Capabilities**:
   * pick your **Team**;
   * **+ Capability → Push Notifications**;
   * **+ Capability → Background Modes** and tick **Audio, AirPlay, and Picture
     in Picture** and **Remote notifications** (already listed in `Info.plist`).

> Pictures in iOS notifications additionally need a *Notification Service
> Extension* (see the FlutterFire Messaging docs, "Displaying an image").
> Without it iPhones show the title and text only — Android shows the banner
> image out of the box. The Cloud Functions already send everything the
> extension needs.

## 8. Google Maps API keys

The Prasadi places map uses the Google Maps SDKs. Opening Google Maps or
Street View for directions uses normal map links and needs no key.

1. Open <https://console.cloud.google.com/google/maps-apis/api-list> and make
   sure the **Firebase project** is selected at the top.
2. **Enable** these APIs: **Maps SDK for Android** and **Maps SDK for iOS**.
3. **Credentials → Create credentials → API key** — create **two keys**:

   | Key | Application restriction | API restriction |
   |---|---|---|
   | `Jetalpur Android Maps` | **Android apps**: package `com.jetalpurdham.app` + every SHA-1 (debug, upload key, Play App Signing) | Maps SDK for Android |
   | `Jetalpur iOS Maps` | **iOS apps**: bundle id `com.jetalpurdham.app` | Maps SDK for iOS |

4. Put them where the build reads them (both files are git-ignored):

   **Android** — `android/local.properties` (add a line):

   ```properties
   MAPS_API_KEY=AIza...your-android-key...
   ```

   For CI you can instead set an environment variable `MAPS_API_KEY`.

   **iOS** — copy the example and fill it in:

   ```bash
   cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
   ```

   ```
   GOOGLE_MAPS_API_KEY = AIza...your-ios-key...
   ```

Never put these keys in Firestore or commit them. Restricted keys are safe
inside the app bundle.

## 9. Deploy rules, indexes and Cloud Functions

From the project folder:

```bash
firebase login
cp .firebaserc.example .firebaserc        # Windows: copy .firebaserc.example .firebaserc
# edit .firebaserc and replace your-firebase-project-id with your project id
# (or run: firebase use --add)

cd functions && npm ci && cd ..
firebase deploy --only firestore,storage,functions
```

What this deploys:

| File | What it does |
|---|---|
| `firestore.rules` | Content is public read-only; devotees can only *create* a validated donation form; everything else is locked. |
| `firestore.indexes.json` | No composite indexes — the app sorts on the phone, so a missing field never hides content. |
| `storage.rules` | Kirtans, gallery, books, places, events and config files are readable by the app; only the console (or an `admin` user) can upload. |
| `functions/` | `onEventWrite`, `onNotificationCreate`, `onStorageUpload`, `onStorageDelete`, `onDonationRequestCreate` in `asia-south1`. |

The first Functions deploy takes 5–10 minutes. The CLI may ask to enable APIs
(Cloud Functions, Cloud Build, Artifact Registry, Eventarc, Cloud Run, Pub/Sub)
— answer **yes**. If it asks about a **cleanup policy for container images**,
answer **yes** with the suggested 1 day; it avoids small storage charges.

> If the very first deploy fails with a permission error mentioning
> *Eventarc* or *Pub/Sub service agent*, Google is still setting up the
> project. Wait 5 minutes and run the same command again.

Check: **Build → Functions** lists five functions in `asia-south1`.

**Developers** can run the unit tests with `cd functions && npm test`, and try
everything locally with the emulators:
`firebase emulators:start --project demo-jetalpur` (needs Java 21).

## 10. Load the starter content (seed)

The seed adds the temple information, darshan timings, the 9 Prasadi places
with their mahima in English/ગુજરાતી/हिन्दी, kirtan and book categories, the
**Avsar 200** album and its event, and the donation settings shape (disabled
until staff fill in the real details).

```bash
cd tools/seed
npm install
gcloud auth application-default login          # signs in as you
node seed.mjs --project <your-project-id> --dry-run   # shows what it would do
node seed.mjs --project <your-project-id>
```

No `gcloud`? Use a service-account key instead: Firebase console → ⚙ **Project
settings → Service accounts → Generate new private key**, save it as
`tools/seed/service-account.json` (git-ignored), then

```bash
# macOS/Linux
GOOGLE_APPLICATION_CREDENTIALS=service-account.json node seed.mjs --project <your-project-id>
# Windows PowerShell
$env:GOOGLE_APPLICATION_CREDENTIALS="service-account.json"; node seed.mjs --project <your-project-id>
```

and **delete the key file** afterwards (and the key under *Service accounts →
Manage service account permissions* in Google Cloud).

The seed is safe to run again at any time: it only adds documents and fields
that are missing and **never overwrites** anything staff have edited.
(Developers who corrected `seed-data.json` can add `--overwrite` to replace
the seeded fields' values; empty placeholders and the payment settings in
`config/donation` are never overwritten. Try it with `--dry-run` first.)

> Run the seed **before** uploading Avsar 200 photos, so the album gets its
> proper title (otherwise it is created automatically as "Avsar 200" and the
> seed keeps that title).

Then work through the **"Before launch" checklist** in
[ADMIN_GUIDE.md](ADMIN_GUIDE.md#before-launch-checklist--લૉન્ચ-પહેલાંની-ચકાસણી):
darshan timings, contact numbers, map pins and donation details all need the
temple office's confirmation.

## 11. Optional: photo thumbnails (Resize Images extension)

The app already shrinks photos on the phone, but small thumbnails make the
photo grid load faster on slow connections and save download costs.

1. Console → **Build → Extensions → Explore** → **Resize Images** (by Firebase) → **Install**.
2. Settings:

   | Setting | Value |
   |---|---|
   | Cloud Functions location | **asia-south1 (Mumbai)** |
   | Cloud Storage bucket | your default bucket |
   | Sizes of resized images | `600x600` |
   | Deletion of original file | **Don't delete** ⚠ (the app needs the full photo) |
   | Make resized images public | No |
   | Cloud Storage path for resized images | `thumbs` |
   | Paths that contain images you want to resize | `/gallery` |
   | Cache-Control header | `max-age=31536000` |
   | Convert image to preferred types | `jpeg` (or `webp`) |

Our `onStorageUpload` function recognises `gallery/<album>/thumbs/<name>_600x600.jpg`
(and any file the extension marks with its `resizedImage` metadata) and stores
it as `thumbUrl` on the matching photo — nothing else to do. Thumbnails are
never counted as photos. Do not put your own photos in a `thumbs` folder.

## 12. Optional: donation e-mails (Trigger Email extension)

When a devotee taps **Contact Now → Submit details** on the donation screen,
the request is stored in `donation_requests`. To also get an e-mail:

1. Create an e-mail account the app can send from. With Gmail: turn on
   2-Step Verification, then create an **App password**
   (<https://myaccount.google.com/apppasswords>).
2. Console → **Extensions → Trigger Email from Firestore** → **Install**:

   | Setting | Value |
   |---|---|
   | Cloud Functions location | **asia-south1 (Mumbai)** |
   | Firestore Instance ID | `(default)` |
   | Firestore Instance Location | **asia-south1** (where you created Firestore in step 4) |
   | Authentication Type | **Username & Password** |
   | SMTP connection URI | `smtps://your.address@gmail.com@smtp.gmail.com:465` |
   | SMTP password | the App password from step 1 |
   | Email documents collection | `mail` |
   | Default FROM address | `Jetalpur Dham App <your.address@gmail.com>` |

3. In Firestore open `config/donation` and set **`notifyEmail`** to the address
   (or several, separated by commas) that should receive alerts, e.g.
   `office@example.org, trustee@example.org`.

Each new request now writes `mail/donation-<id>`, and the extension sends a
neat summary (name, phone, amount, purpose, method, transaction no., message)
with **reply-to** set to the devotee's e-mail. Without the extension nothing
breaks — staff still see every request in the console.

> `config/donation` is readable by the app, so use the temple's official
> address for `notifyEmail`, not a personal one.

## 13. Test a push notification

Install the app on a phone (step 15 or `flutter run`), open it once and allow
notifications. Each phone subscribes to one topic for its language:
`lang_en`, `lang_gu` or `lang_hi`.

* **Quick test from the console:** **Messaging** (left menu, under *Run* or
  *Engage* depending on the console version) → **New campaign →
  Notifications** → title and text → *Target*: **Topic** `lang_en` (repeat for
  `lang_gu` / `lang_hi`) → *Additional options → Custom data*: key `route`,
  value `/events` → **Review → Publish**.
* **The real flow:** add a test event with `sendNotification` = `true`
  (see the admin guide). Within a minute every device gets it in its own
  language, the event shows `notifiedAt` and `notificationStatus: "sent"`, and
  tapping the notification opens that event.
* **Ad-hoc message:** add a document to `notifications` with `title` and
  `body`; the function writes `status: "sent"` back to it.

Delete your test documents afterwards.

## 14. Android release signing

Create an upload key once and keep it (and its passwords) safe — you need the
same key for every future update.

```bash
keytool -genkey -v -keystore ~/jetalpur-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Create `android/key.properties` (git-ignored):

```properties
storePassword=<the store password>
keyPassword=<the key password>
keyAlias=upload
storeFile=/absolute/path/to/jetalpur-upload.jks
```

`android/app/build.gradle.kts` picks it up automatically (without it, release
builds fall back to debug signing so `flutter run --release` still works).
Add the upload key's SHA-1 (`keytool -list -v -keystore ~/jetalpur-upload.jks -alias upload`)
to Firebase and to the Android Maps key.

## 15. Build and publish

```bash
flutter pub get
flutter gen-l10n
flutter analyze && flutter test
```

**Android (Play Store)**

```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Create the app in Play Console, upload the `.aab` to an internal testing track
first, and enrol in **Play App Signing**. Then copy the **App signing key
certificate SHA-1** (Play Console → *Test and release → App integrity*) into
Firebase (Android app fingerprints) and into the Android Maps key restriction.
Once published, put the Play Store link in `config/app.shareUrl` so "Share App"
works.

**iOS (App Store)**

```bash
flutter build ipa --release
# → build/ios/ipa/*.ipa  (and build/ios/archive/Runner.xcarchive)
```

Upload with Xcode → *Window → Organizer → Distribute App*, or with Apple's
**Transporter** app, then test through TestFlight before submitting for review.

**App icon and splash** (already generated; regenerate after changing the
artwork in `assets/icons/`):

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## 16. Troubleshooting

| Problem | What to check |
|---|---|
| App shows no content | `lib/firebase_options.dart` still the placeholder? Run step 6. Seed loaded (step 10)? |
| An uploaded kirtan/photo/PDF does not appear | Folder name must match a category/album id; file must be MP3/M4A, JPEG/PNG/WebP or PDF. Console → **Functions → Logs** for `onStorageUpload`. iPhone HEIC photos are skipped — export as JPEG. |
| Notification not received | Phone: app notifications allowed and switched on in app *Settings*. Event: `notificationStatus` / `notificationError` fields. iOS: APNs key uploaded (step 7) and Push capability added. |
| Map is blank/grey | Maps key missing or restricted to the wrong package/SHA-1/bundle id (step 8). |
| "Missing or insufficient permissions" in logs | Rules not deployed (step 9), or a donation form field outside the allowed list. |
| Functions deploy fails with a region/location error | Firestore and Storage must be in `asia-south1`, or change `REGION` in `functions/src/config.ts` to their location. |
| Need to re-send an event notification | Delete the event's `notifiedAt` field — it is sent again once. |
