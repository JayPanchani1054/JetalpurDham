# Beta testing — step by step

Jay Shree Swaminarayan! 🙏

Before the Jetalpur Dham app goes to the Play Store and the App Store, a small
group of devotees uses a **test version** (a *beta*) for two to three weeks and
tells us what is wrong or confusing. This guide explains, step by step, how to
give them the app, what to ask them to try, and how they report problems.

**Who does what**

| Who | Does |
|---|---|
| **Developer** | Makes the builds, uploads them, checks crash reports (sections 2–6). |
| **Beta coordinator** (temple office or a volunteer) | Collects tester e-mail addresses, sends invitations, shares the checklist, collects reports (sections 4, 5, 7, 8). |
| **Testers** (devotees) | Install the app, try everything on the checklist, report problems (sections 7–8). |

**Contents**

1. [Quick preview — the demo APK (no setup)](#1-quick-preview--the-demo-apk-no-setup)
2. [Before the first beta build](#2-before-the-first-beta-build)
3. [The one rule: a new build number every time](#3-the-one-rule-a-new-build-number-every-time)
4. [Android testers](#4-android-testers)
   — [4a. Firebase App Distribution](#4a-firebase-app-distribution)
   · [4b. Play internal testing](#4b-google-play-internal-testing)
   · [4c. Play closed testing (12 testers × 14 days)](#4c-google-play-closed-testing)
5. [iPhone testers — TestFlight](#5-iphone-testers--testflight)
6. [Check that crash reports arrive](#6-check-that-crash-reports-arrive)
7. [Tester checklist](#7-tester-checklist)
8. [How testers report a problem](#8-how-testers-report-a-problem)
9. [Suggested timeline](#9-suggested-timeline)
10. [After the beta](#10-after-the-beta)

---

## 1. Quick preview — the demo APK (no setup)

Want to *see* the app today, before Firebase is set up? Every change to the
code automatically builds a **demo app** with sample content (the real temple
history, prasadi places and mahima, kirtan and shastra names, with placeholder
photos, a sample PDF and tanpura audio).

**Download it**

1. Open the project on GitHub → **Actions** tab → workflow **Build apps**
   (<https://github.com/JayPanchani1054/JetalpurDham/actions/workflows/build.yml>).
   You need to be signed in to GitHub.
2. Click the newest run with a green ✓. (No recent run? Click **Run workflow**
   to start one; it takes about 15 minutes.)
3. Scroll to **Artifacts** and download **`jetalpur-dham-demo-apk`**. It is a
   `.zip` file — unzip it to get `jetalpur-dham-demo.apk`. Artifacts are kept
   for 30 days.

**Install it on an Android phone**

1. Send the `.apk` to the phone (Google Drive, WhatsApp *as a document*, or a
   USB cable) and tap it.
2. If Android asks, allow **Install unknown apps** for the app you opened it
   from (Drive, Files, WhatsApp).
3. If *Play Protect* warns about an unknown app, tap **More details → Install
   anyway**. (The demo is not from the Play Store, so this is expected.)

**Good to know**

* The demo needs **no internet setup** and no Firebase project. Notifications,
  the Google map (places open as a list) and donation payments are switched
  off; everything else can be explored. A short welcome message says so the
  first time it opens.
* It is **for looking only** — do not report the sample photos, audio or PDF
  as bugs.
* It installs as a separate app called **"Jetalpur Dham Demo"**, next to the
  real app (and the beta), and a newer demo APK installs over the older one.
* If the phone says *"App not installed"* or *"conflicts with an existing
  package"* when you install a **beta**, uninstall any older app called just
  **"Jetalpur Dham"** that did not come from the beta invitation (for example
  a very early demo), then try again.
* Ignore the artifact **`jetalpur-dham-release-apk`**: it is the real app
  without the temple's Firebase connection and signed with a test key, so it
  shows no content and must not be shared.
* **iPhone or a big screen?** Download **`jetalpur-dham-web-demo`**, unzip it,
  and in that folder run `python3 -m http.server 8080`; then open
  <http://localhost:8080> in a browser (it must be served like this — opening
  `index.html` directly does not work).

---

## 2. Before the first beta build

Testers should see the **real** app with real content. Tick these off first
(details in [FIREBASE_SETUP.md](FIREBASE_SETUP.md) and
[ADMIN_GUIDE.md](ADMIN_GUIDE.md)):

* [ ] Firebase connected (`flutterfire configure`, step 6), rules and functions
  deployed (step 9), seed loaded (step 10).
* [ ] **Content uploaded** — at least a few kirtans in every category, the main
  shastra PDFs, the Avsar 200 photos and one upcoming utsav. Empty screens
  ("will be added soon") make testers — and Apple's beta reviewers — think the
  app is broken.
* [ ] `config/app`: **e-mail** (or WhatsApp) filled in — the **Send feedback**
  item in Settings stays hidden until one of them is set.
* [ ] Google Maps keys set (step 8) — otherwise the Prasadi map is blank.
* [ ] **Upload key** created (step 14) — every Android tester build must be
  signed with it.
* [ ] `config/donation.notifyEmail` empty or a test address while testers
  practise the donation form (step 12).
* [ ] **iPhone:** the temple website's donation page published and its address
  in `config/donation.webUrl` — the iPhone app's only donation button opens it
  ([ADMIN_GUIDE.md § 8](ADMIN_GUIDE.md#8-update-donation-details--દાનની-વિગતો)).
* [ ] **Do not** switch on App Check enforcement — the app does not contain
  App Check yet, and enforcing it hides all content
  ([FIREBASE_SETUP.md step 12](FIREBASE_SETUP.md#12-optional-donation-e-mails-trigger-email-extension)).
* [ ] **Privacy policy** published and its address saved in
  `config/app.privacyPolicyUrl` (needed for Play closed testing and TestFlight
  external testing — see [STORE_SUBMISSION.md](STORE_SUBMISSION.md#1-privacy-policy-address)).
* [ ] Developer accounts created — ideally **organization** accounts in the
  trust's name ([STORE_SUBMISSION.md § 0](STORE_SUBMISSION.md#0-who-publishes-the-app)).
  This decides whether you need the 14-day closed test in 4c.

---

## 3. The one rule: a new build number every time

`pubspec.yaml` contains `version: 1.0.0+1`. The number after the `+` is the
**build number**. Every build you give to testers — through App Distribution,
Play or TestFlight — must have a **higher** build number than the one before.

```bash
# either edit pubspec.yaml to 1.0.0+2, 1.0.0+3, … and commit, or:
flutter build appbundle --release --build-number=2   # Play
flutter build apk --release --build-number=2         # App Distribution
flutter build ipa --release --build-number=2         # TestFlight (Mac)
```

Use the **same** number for the Android and iPhone builds made from the same
code. Testers see it in **Settings → About app** as, for example,
*Version 1.0.0 (2)* — so every report tells you exactly which build it is about.

---

## 4. Android testers

Three ways, from quickest to most "real". Most temples use **4a** for the first
days, then **4b/4c**.

| | Who can test | Review by Google | Best for |
|---|---|---|---|
| **4a. Firebase App Distribution** | anyone you invite by e-mail | none | the first, fast rounds |
| **4b. Play internal testing** | up to 100 people | none | the core team, testing the real Play install |
| **4c. Play closed testing** | e-mail list of devotees | yes (first time can take a few days) | the wider beta — and **required** for new personal accounts |

### 4a. Firebase App Distribution

**Developer — once:** Firebase console → **App Distribution** (left menu,
under *Release & Monitor* or *Run*) → choose the Android app → **Get started**.
Then **Testers & Groups → Add group**, e.g. `devotees`, and add the testers'
e-mail addresses. Testers sign in with a **Google account** to accept the
invitation, so invite the Gmail address they use on their phone.

**Developer — every build:**

```bash
flutter build apk --release --build-number=<N>
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app <ANDROID_APP_ID> \
  --groups "devotees" \
  --release-notes "Build N: what changed and what to test"
```

`<ANDROID_APP_ID>` looks like `1:1234567890:android:abc123…` — Firebase ⚙
*Project settings → Your apps → Android → App ID* (also `appId` in the
`android` section of `lib/firebase_options.dart`).

*No command line?* In **App Distribution → Releases**, drag the `.apk` onto the
page, pick the group, write release notes and click **Distribute**.

**Testers:** open the invitation e-mail **on the phone**, sign in with Google,
accept, and follow the steps to download and install (allow *Install unknown
apps* when asked). New builds arrive the same way.

> **Moving to the Play version later:** App Distribution builds are signed
> with the upload key; the Play Store re-signs with Google's own key. When a
> tester switches from an App Distribution build to the Play testing build,
> they must **uninstall first**. Downloads and settings are lost — that is
> normal.

### 4b. Google Play internal testing

1. Play Console → **Create app**: name *Jetalpur Dham*, default language,
   *App*, *Free*; accept the declarations.
2. **Test and release → Testing → Internal testing → Testers → Create email
   list** — add up to 100 Google-account e-mails → **Save**.
3. **Create new release** → upload `app-release.aab` (built with the upload
   key and a new build number) → release notes → **Next → Save and publish**.
4. Copy the **"Join on the web"** link and send it to the testers. Each tester
   opens it **signed in with the same Google account as on their phone**, taps
   **Accept invitation / Become a tester**, then installs *Jetalpur Dham* from
   the Play Store link on that page. Builds usually appear within minutes.

### 4c. Google Play closed testing

> **The 12-testers-for-14-days rule.** Google Play requires **personal**
> developer accounts created after 13 November 2023 to run a **closed test
> with at least 12 testers who stay opted in for at least 14 days in a row**
> before the app can go to Production. Internal testing (4b) does **not**
> count. ([Google's help page](https://support.google.com/googleplay/android-developer/answer/14151465))
>
> **Organization accounts are exempt.** Registering the Play Console account
> as an **organization in the trust's name** (with the trust's D-U-N-S number)
> skips this rule *and* shows the trust as the publisher, which also helps
> with the permission check in [STORE_SUBMISSION.md](STORE_SUBMISSION.md#0-who-publishes-the-app).
> **We recommend registering as the trust.**

If you do have a new personal account:

1. **Test and release → Testing → Closed testing** → open the default track
   (or **Create track**) → **Testers** → **Create email list** with **15–20
   devotees** (a few spare, in case someone drops out) → **Save**.
2. **Create new release** → upload the `.aab` → **Save → Send for review**.
   The first closed release is reviewed by Google (often a day or two, up to
   several days).
3. When it is approved, share the **opt-in link**. Each tester taps **Become a
   tester** with the Google account on their phone and installs the app from
   the Play Store.
4. Keep **at least 12 testers opted in for 14 days in a row**. Ask testers not
   to leave the programme and to open the app every day or two. Start counting
   from the day the 12th tester joined.
5. After 14 days: Play Console **Dashboard → Apply for production**. Google
   asks how you tested (who the testers were, what feedback you got, what you
   changed) — the reports from section 8 are your answers. Google usually
   replies within about a week.

---

## 5. iPhone testers — TestFlight

TestFlight is Apple's free beta app. We recommend it over Firebase App
Distribution for iPhones: App Distribution would need every tester's device ID
registered by hand.

**a. Create the app record (once).** <https://appstoreconnect.apple.com> →
**Apps → + → New App**: platform **iOS**, name *Jetalpur Dham* (must be unique
on the App Store), primary language, bundle ID **com.jetalpurdham.app**, SKU
`jetalpur-dham-ios`, user access *Full access*. The upload in the next step
fails until this record exists.

**b. Upload a build (Mac).**

```bash
flutter build ipa --release --build-number=<N>
```

Open Apple's **Transporter** app, sign in, drag in the `.ipa` from
`build/ios/ipa/` and click **Deliver**. After 10–30 minutes the build appears
under the **TestFlight** tab (Apple e-mails you). The export-compliance
question is already answered in the app (no special encryption). Builds can be
tested for **90 days**.

**c. Internal testers — no review, minutes.** Up to **100** people who are
users of your App Store Connect team (add them first under **Users and
Access**, any role). TestFlight tab → **Internal Testing → +** → create a group
→ **Invite Testers** → **Add Builds**.

**d. External testers — devotees, after a short Apple review.**

1. TestFlight tab → **Test Information**: **Beta App Description** (what the
   app is and what to test) and **Feedback Email** (the beta coordinator's
   address) are required; also fill in the privacy policy address and the
   review contact details. Sign-in is **not** required.
2. **External Testing → +** → create a group (e.g. *Devotees*) → **Add
   Builds** → choose the build → write **What to Test** → **Submit Review**.
   The first build of each version gets a full *TestFlight App Review*
   (usually within a day or two); later builds of the same version are often
   approved faster.
3. Add testers by e-mail, or switch on a **public link** and share it (you can
   cap the number of testers).

**Testers:** install the free **TestFlight** app from the App Store, open the
invitation (e-mail or link), tap **Accept → Install**. New builds show up in
TestFlight; turn on automatic updates there.

> **Before external testing:** Apple reviews external betas with the same
> rules as the App Store. The content must be ready, and
> `config/donation.webUrl` must point to the temple's donation page — on
> iPhone the Donate screen only links there (Apple's donation rule, see
> [STORE_SUBMISSION.md § 4.1](STORE_SUBMISSION.md#41-donations-on-iphone--guideline-322iv-)).
> Internal testing (c) is not reviewed.

---

## 6. Check that crash reports arrive

The app sends crash reports to **Firebase Crashlytics** — from release
builds (never from the debug builds used while developing), and only if the
user has not switched off *Settings → Share crash reports*. Check this **once
on Android and once on iPhone** before the wider beta, so a broken setup is
not discovered only after testers have had crashes.

**1. Force one test crash with a throw-away build** (developer). Create this
temporary file — do **not** commit it and never upload this build:

```dart
// lib/main_crash_test.dart — TEMPORARY: delete after the test.
import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'bootstrap.dart';

Future<void> main() async {
  await bootstrap();
  // Crash 10 seconds after start so Crashlytics receives a test report.
  Timer(const Duration(seconds: 10), FirebaseCrashlytics.instance.crash);
}
```

Then, with a phone connected by USB:

```bash
flutter run --release -t lib/main_crash_test.dart
```

1. Wait for the crash (10 seconds after the app opens).
2. Stop `flutter run` (press `q`), then **open the app again from the home
   screen** — Crashlytics sends the report when the app starts the next time.
   (On iPhone, always start it from the home screen: a connected debugger
   would catch the crash instead.)
3. Within about 5 minutes, Firebase console → **Crashlytics** → your Android
   / iOS app shows the crash. Check that the stack trace is readable.
4. **Delete `lib/main_crash_test.dart`** and reinstall a normal build.

**2. Readable reports in real beta builds.** For Play / App Distribution and
TestFlight builds, the setup from [FIREBASE_SETUP.md](FIREBASE_SETUP.md) step 6
uploads the files that turn crash addresses into readable code lines:

* Android — the Crashlytics Gradle plugin uploads the mapping file during
  `flutter build appbundle/apk --release` (task
  `uploadCrashlyticsMappingFileRelease`).
* iPhone — the *Crashlytics Upload Symbols* build phase uploads the dSYM
  files. If Crashlytics shows a **"missing dSYM"** banner, that phase is
  missing (re-run `flutterfire configure` on the Mac).

**3. During the beta** look at Crashlytics every few days. Without Google
Analytics, Crashlytics shows the crashes and errors themselves but may not
show "crash-free users" percentages — that is expected.

---

## 7. Tester checklist

Share this list with every tester (it is fine to split it: one group tries
kirtans, another the places and shastras). Please try on **mobile data and
Wi-Fi**, and write down anything that is slow, wrong, confusing, or simply not
nice.

**First start**
- [ ] The opening screen shows the murti darshan, then Home.
- [ ] On iPhone and on Android 13 or newer, a short explanation appears
  before the phone's notification question; tap **Continue** and choose
  *Allow* (or *Don't allow* — the app should work either way).

**Kirtan**
- [ ] Open a category and play a kirtan — it starts within a few seconds.
- [ ] Pause, seek with the slider, next / previous.
- [ ] Lock the phone: the kirtan **keeps playing**; the **lock screen** (and
  the Android notification) shows the title with play/pause and next.
- [ ] Use another app for a minute — playback continues.
- [ ] Search for a kirtan in English, ગુજરાતી and हिन्दी.
- [ ] **Download** a kirtan. Switch on **airplane mode** and play it from
  *My Downloads* (menu) — it plays without internet.
- [ ] Remove a download (and later *Settings → Storage → Remove all*).

**Prasadi places — map and 360°**
- [ ] The map shows the pins (a grey, empty map is a bug — please report it).
- [ ] Switch between map and list; open a place.
- [ ] Read the mahima; swipe through the photos.
- [ ] Open **360° darshan**: look around by swiping and by moving the phone.
- [ ] **Street View** and **Directions** open Google Maps at the right spot.

**Photo gallery (Avsar 200)**
- [ ] Home → Avsar 200 → open an album; photos load quickly while scrolling.
- [ ] Open a photo full screen, pinch to zoom, swipe to the next one.
- [ ] **Save** a photo — allow access when asked — and find it in the phone's
  gallery / Photos.
- [ ] **Share** a photo to WhatsApp.

**Shastra library (PDF)**
- [ ] Open a shastra; scrolling and zooming are smooth.
- [ ] Read to some page, close the book, open it again — it **continues on
  the same page**.
- [ ] **Download** a big shastra; while it downloads, switch the internet off
  for a moment and on again — the download completes (or can be restarted)
  and the book then opens in **airplane mode**.

**Utsav and notifications**
- [ ] The Utsav tab shows upcoming events first and past events separately.
- [ ] Open an event: banner, details, and the *View photos* / *Watch live*
  buttons if shown.
- [ ] When the coordinator sends a **test notification**: it arrives in your
  app language; tapping it opens **that** utsav — try once with the app open,
  once in the background, and once after closing the app completely.
- [ ] Switch *Settings → Utsav notifications* off: no more notifications.

**Donation**
- [ ] Home → Donate. **Android:** the UPI QR, *Pay with UPI app* (opens your
  UPI app — **do not pay** unless the coordinator asks for a ₹1 test) and the
  bank details with **copy** buttons. **iPhone:** one **Donate on the temple
  website** button that opens the temple's donation page in Safari — no QR,
  bank details or form (that is on purpose, Apple's rule).
- [ ] **Android:** **Contact Now** → *Share Donation Details* form: fill it in
  with your name starting with **TEST** and submit; a short privacy note with
  a *Privacy policy* link is shown on the form.
- [ ] Call, WhatsApp and e-mail buttons open the right app.

**Languages, look and comfort**
- [ ] Change the language with the button at the **top right** and in the
  menu — English, ગુજરાતી, हिन्दी. Report any text still in the wrong
  language, cut off, or translated awkwardly.
- [ ] Switch the phone to **dark mode** — every screen is readable.
- [ ] Set the phone's **font size to the largest** — text still fits, nothing
  overlaps (important for elderly devotees).
- [ ] **Back navigation:** Android back button / gesture and iPhone
  swipe-from-the-left-edge always go one step back; from another tab, back
  goes to Home; with the side menu open, back closes the menu.
- [ ] Tablet or foldable (if you have one): turn it sideways — screens still
  look right.

**Settings and the rest**
- [ ] About Temple shows the history and darshan timings; its *Contact*
  buttons (call, WhatsApp, e-mail, website) open the right app.
- [ ] *Share App* (menu), *Settings → Privacy policy* and *Settings → Legal
  notices & licences* open.
- [ ] *Settings → Send feedback* opens an e-mail (or WhatsApp) to the temple.
- [ ] Turn on **airplane mode** and open screens you visited before: they
  still show content, and a friendly offline message appears.
- [ ] **Update test:** when a new build arrives, install it over the old one —
  downloads and settings are kept.

---

## 8. How testers report a problem

**In the app:** **Settings → Send feedback** (under *About app*; in Gujarati
*સેટિંગ્સ → પ્રતિસાદ મોકલો*, in Hindi *सेटिंग्स → सुझाव भेजें*; Settings is
in the side menu ☰). It opens an e-mail (or WhatsApp) to the temple with the
**app version and the phone's system (Android or iOS) and its version string
already filled in** — write above them, and add your phone model (for example
"Samsung Galaxy A14"), which the app does not include.

**On iPhone with TestFlight** you can also take a screenshot and tap **Share
Beta Feedback**, or open TestFlight → Jetalpur Dham → **Send Beta Feedback**.
This goes to the *Feedback Email* set in section 5.

**Otherwise** send the coordinator an e-mail or WhatsApp message and include
the version from **Settings → About app** (for example *Version 1.0.0 (3)*).

**A good report says:**

1. **What you did** — "Kirtan → Aarti → tapped the first kirtan".
2. **What happened** — "nothing played for 30 seconds".
3. **What you expected** — "it should start playing".
4. A **screenshot** or short **screen recording**, if possible.
5. Your **phone** (e.g. *Samsung A15, Android 15* / *iPhone 13, iOS 26*), the
   **app language**, and whether you were on **Wi-Fi, mobile data or
   offline**.

The coordinator keeps one list (a shared spreadsheet is enough) with a column
for the **build number**, and marks each item *fixed in build N* — testers
then re-check it in that build.

**Invitation message you can copy**

> Jay Shree Swaminarayan 🙏 We are testing the new Jetalpur Dham app before it
> goes to the Play Store / App Store, and would be grateful for your help for
> about two weeks. Please install it from the link below, use it every day or
> two, and tell us anything that does not work or is hard to understand —
> *Settings → Send feedback* in the app. Link: …

> જય શ્રી સ્વામિનારાયણ 🙏 જેતલપુર ધામની નવી એપ પ્લે સ્ટોર / એપ સ્ટોર પર
> આવે તે પહેલાં અમે તેનું પરીક્ષણ કરી રહ્યા છીએ. લગભગ બે અઠવાડિયાં માટે
> આપની મદદ મળશે તો ખૂબ આનંદ થશે. નીચેની લિંક પરથી એપ ઇન્સ્ટોલ કરશો, દર
> એક-બે દિવસે તેનો ઉપયોગ કરતા રહેશો, અને કંઈ બરાબર ન ચાલે કે સમજાય નહીં તો
> એપમાં *સેટિંગ્સ → પ્રતિસાદ મોકલો* દ્વારા જરૂર જણાવશો. લિંક: …

---

## 9. Suggested timeline

| When | What |
|---|---|
| Before you start | Request the trust's **D-U-N-S number** and the **developer accounts** (allow up to two weeks); written permission from the trust ([STORE_SUBMISSION.md § 0](STORE_SUBMISSION.md#0-who-publishes-the-app)). |
| Week 0 | Firebase setup, content upload, privacy policy published. Developer checks crash reports (section 6). |
| Week 1 | **Core team** (5–10 people): App Distribution or Play internal testing, TestFlight internal. Fix the big problems. |
| Weeks 2–3 | **Devotees** (15–20+): Play closed testing (14 days if required) and TestFlight external. New build every few days. |
| Week 4 | Last fixes, store listing and declarations ([STORE_SUBMISSION.md](STORE_SUBMISSION.md)), apply for Play production, submit to the App Store. |

---

## 10. After the beta

* Delete test documents: `donation_requests` whose name starts with **TEST**,
  test events and test `notifications`.
* Set `config/donation.notifyEmail` to the office address
  ([FIREBASE_SETUP.md](FIREBASE_SETUP.md) step 12). Leave App Check
  enforcement **off** unless a developer has added App Check to the app
  (same step).
* Thank the testers 🙏 — they can keep the app; the store version replaces
  the test version through the Play Store / App Store (App Distribution users
  uninstall first and install from the Play Store).
* Continue with [STORE_SUBMISSION.md](STORE_SUBMISSION.md).

Jay Shree Swaminarayan 🙏
