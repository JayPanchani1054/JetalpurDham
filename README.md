# Jetalpur Dham

The official app of **Shree Swaminarayan Mandir, Jetalpur Dham** (Gujarat,
India) — home of **Shree Revati Baldevji Harikrushna Maharaj**, the fifth of
the nine mandirs Bhagwan Shree Swaminarayan established Himself.

A calm, simple devotional app for Android and iPhone in **English, ગુજરાતી and
हिन्दी**, designed for devotees of every age. All content is managed by temple
staff in the Firebase console — there is no separate admin panel.

## Features

| | |
|---|---|
| 🎵 **Kirtan** | 100+ kirtans by category with instant streaming, background playback with lock-screen controls, search in any script, and one-tap download for offline listening. |
| 🛕 **Prasadi places** | Map of the sacred places sanctified by Shreeji Maharaj with their *mahima*, photos, in-app 360° darshan and Google Street View / directions. |
| 📸 **Avsar 200 gallery** | Photos of the *Avsar* Dwishatabdi Mahotsav (5–11 March 2026) and future utsavs — full-screen viewer, save to phone, share. |
| 📚 **Shastra library** | PDFs of Sampraday scriptures (Vachanamrut, Shikshapatri, …) with a smooth reader that remembers your page and works offline once downloaded. |
| 🔔 **Utsav & katha** | Upcoming and past events with banners and details; push notifications in each devotee's language that open the right event. |
| 🙏 **Donation** | UPI QR, "Pay with UPI app", bank details with copy buttons, and a simple "Contact Now" form so the office can confirm and send a receipt. |
| 🌐 **Three languages** | Language switch at the top-right of every screen and in the menu; English first, then Gujarati and Hindi. |
| 🌙 **Comfortable** | Large readable text, light and dark themes, offline support, skeleton loading and friendly error states. |

## Screenshots

> Add store screenshots here before publishing (Home, Kirtan player, Prasadi
> map, Avsar gallery, Shastra reader, Utsav, Donation — in each language).

| Home | Kirtan | Prasadi places | Avsar 200 |
|---|---|---|---|
| _screenshot_ | _screenshot_ | _screenshot_ | _screenshot_ |

## Tech stack

| Area | Choice |
|---|---|
| App | Flutter 3.47 · Dart 3.13 · Material 3 (`material_ui`) |
| State | Riverpod 3 (`Provider`, `StreamProvider`, `NotifierProvider`, families) |
| Navigation | go_router 18 — `StatefulShellRoute` with five tabs, deep links from notifications |
| Backend | Firebase: Cloud Firestore, Cloud Storage, Cloud Messaging, Cloud Functions (2nd gen, Node 22, TypeScript), Crashlytics, Analytics |
| Audio | just_audio + just_audio_background (lock screen / notification controls) |
| Media | cached_network_image, photo_view, gal (save photos), pdfrx (PDF), panorama_viewer (360°), google_maps_flutter |
| Localization | ARB files (`lib/l10n/arb/app_{en,gu,hi}.arb`) + `LocalizedText` for Firestore content |

## Architecture

```
lib/
  main.dart, bootstrap.dart   start-up: Firebase, offline cache, Crashlytics, audio, notifications
  app.dart                    MaterialApp.router, theme, language, notification topic sync
  core/                       shared foundation used by every feature
    config/                   config/app document (temple info, darshan timings)
    firebase/                 Firestore/Storage providers, FirestorePaths, Fs.* defensive parsing, media URL resolver
    l10n/                     AppLanguage, language controller, context.l10n
    models/                   LocalizedText ({en, gu, hi} with fallbacks)
    router/                   Routes.*, app router, notification deep links
    services/                 downloads (offline files), connectivity, preferences
    theme/                    colours, spacing, typography (Poppins / Hind Vadodara / Hind)
    utils/ widgets/           logger, formatters, launcher, skeletons, empty/error states, network image…
  features/<feature>/         kirtan · places · gallery · library · events · donation · home · about · settings · shell · splash
    data/ domain/ application/ presentation/
  l10n/                       ARB sources and generated localizations
functions/                    Cloud Functions (TypeScript) — auto content from uploads, push, donation e-mails
tools/seed/                   one-time starter content loader (temple info, prasadi places, categories, Avsar 200)
firestore.rules, storage.rules, firestore.indexes.json, firebase.json
docs/                         DATA_MODEL.md · FIREBASE_SETUP.md · ADMIN_GUIDE.md
```

* **Feature-first.** Each feature owns its models (`domain`), Firestore access
  (`data`), Riverpod controllers (`application`) and screens
  (`presentation`), and builds on the shared `core`.
* **Content contract.** [docs/DATA_MODEL.md](docs/DATA_MODEL.md) is the single
  source of truth for collections, fields and Storage folders, shared by the
  app, the security rules, the Cloud Functions and the seed.
* **Hand-edited data is expected.** Every reader tolerates missing or
  wrongly-typed fields (`Fs.*`), treats a missing `isActive` as visible and
  sorts/filters on the device — no composite indexes, so a forgotten field can
  never make content disappear.
* **Live updates.** Screens listen to Firestore `snapshots()`, so changes made
  in the console appear on phones within seconds.

### Offline strategy

* Firestore offline persistence with an unlimited cache: everything a devotee
  has opened stays readable without internet.
* Kirtans and shastra PDFs can be downloaded into the app's documents folder
  (written to a `.part` file and renamed when complete, so partial files are
  never used); downloaded items play/open first.
* Images are cached on disk and decoded at display size.
* An offline banner explains the state; actions that need the network say so
  politely instead of failing.

### Backend automation (Cloud Functions, `asia-south1`)

| Function | Trigger | What it does |
|---|---|---|
| `onStorageUpload` | file uploaded | `kirtans/<category>/*.mp3` → kirtan, `gallery/<album>/*.jpg` → album photo (+ count, cover, thumbnails), `books/<category>/*.pdf` → book |
| `onStorageDelete` | file deleted | removes the matching document (ignores overwrites) |
| `onEventWrite` | `events/*` written | `sendNotification: true` → one push per language topic, exactly once (`notifiedAt`) |
| `onNotificationCreate` | `notifications/*` created | ad-hoc push; writes `status` / `sentAt` / `error` back |
| `onDonationRequestCreate` | `donation_requests/*` created | e-mails the office via the Trigger Email extension when `config/donation.notifyEmail` is set |

Security: content is public read-only; the only client write is a strictly
validated, create-only donation form; staff use the console (which bypasses
rules) and future tools can use an `admin` custom claim.

## Quick start

```bash
# 1. Firebase project, keys and deploy — follow docs/FIREBASE_SETUP.md, then:
flutter pub get
flutter gen-l10n
flutter run

# Checks
flutter analyze
flutter test
cd functions && npm ci && npm test          # Cloud Functions unit tests
```

Until `flutterfire configure` replaces the placeholder `lib/firebase_options.dart`,
the app starts but shows no remote content.

Secrets are never committed: Google Maps keys live in `android/local.properties`
(`MAPS_API_KEY=…`) and `ios/Flutter/Secrets.xcconfig` (`GOOGLE_MAPS_API_KEY = …`),
release signing in `android/key.properties`.

## Before launch

1. **Murti photo** — replace `assets/images/murti.jpg` with the official darshan
   photo of Shree Revati Baldevji Harikrushna Maharaj (portrait, about
   1080 × 1620, same file name). It is used by the opening screen, the Home
   header, the menu and the About page; a decorative placeholder ships until
   then. (`config/app.heroImageUrl` can also override the Home header remotely.)
2. **Connect Firebase** — `flutterfire configure`, deploy rules and functions,
   run the seed ([docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)).
3. **Confirm facts** — darshan timings, phone/WhatsApp numbers and the map pins of
   the prasadi places came from public sources; confirm them with the temple
   office and correct them in the console.
4. **Donation** — fill `config/donation` (UPI ID, QR image, bank details) and set
   `enabled: true`.
5. **Recommended** — enable Firebase App Check (Play Integrity / App Attest) to
   protect the public donation form from spam, and install the *Resize Images*
   extension so large albums load thumbnails.
6. **Icons/splash** — if the logo changes: `dart run flutter_launcher_icons` and
   `dart run flutter_native_splash:create`.

## Documentation

* **[docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)** — create the Firebase
  project, connect the app, push notifications, Maps keys, deploy, seed,
  signing and publishing (step by step, for non-experts).
* **[docs/ADMIN_GUIDE.md](docs/ADMIN_GUIDE.md)** — for temple staff: add
  kirtans, photos, shastras and utsavs, send notifications, update donation
  details and darshan timings, edit prasadi places (with Gujarati headings).
* **[docs/DATA_MODEL.md](docs/DATA_MODEL.md)** — the Firestore/Storage contract.

## Credits

Fonts: Poppins, Hind Vadodara and Hind under the SIL Open Font License (see
`assets/fonts/LICENSE-OFL.txt`). Starter content compiled from public sources
of the temple and Shree NarNarayan Dev Gadi (Kalupur); to be confirmed by the
temple before launch (see the admin guide's checklist). Murti photographs and
recordings belong to the temple and are used with its permission.

Jay Shree Swaminarayan 🙏
