# Store submission — Google Play and the App Store

This guide lists everything Google Play Console and App Store Connect ask
before the Jetalpur Dham app can be tested widely and published — with the
answers already worked out for this app. Fill it in together: the
**developer** knows the technical side, a **trustee** confirms the trust's
details and gives the permissions in section 0.

> **Keep the answers true.** They describe the app as it is today: no login,
> no ads, no tracking, Crashlytics crash reports, push notifications, and the
> donation details form. If the app later adds a feature, an SDK or new data,
> update the answers here and in both consoles.

**Contents**

0. [Who publishes the app](#0-who-publishes-the-app)
1. [Privacy policy address](#1-privacy-policy-address)
2. [Store listing](#2-store-listing)
3. [Google Play — App content](#3-google-play--app-content)
4. [App Store (iOS)](#4-app-store-ios)
5. [Notes for the app reviewers (template)](#5-notes-for-the-app-reviewers-template)
6. [Permission letter from the trust (template)](#6-permission-letter-from-the-trust-template)
7. [Final checklist before you press Submit](#7-final-checklist-before-you-press-submit)
8. [After approval](#8-after-approval)

---

## 0. Who publishes the app

The app uses the **temple's name, murti photographs, kirtan recordings and
scripture texts**. Both stores require that an app like this is submitted by
the owner of that material or with its written permission:

* **Apple 5.2.1:** *"Apps should be submitted by the person or legal entity
  that owns or has licensed the intellectual property and other relevant
  rights."* Apple may ask for proof at any time (5.2.2).
* **Google Play Impersonation policy:** an app must not suggest it is made or
  approved by an organization it is not connected to — a title with
  "Official" needs that organization's permission.

**Recommended: publish under the trust's own accounts.**

| | Google Play Console | Apple Developer Program |
|---|---|---|
| Account type | **Organization**, in the trust's legal name | **Organization**, in the trust's legal name |
| Needs | D-U-N-S number, trust website, official e-mail and phone | D-U-N-S number, legal entity status, a trustee (or someone authorised) who can sign for the trust |
| Cost | one-time registration fee | yearly fee — a registered nonprofit can ask for a **fee waiver** during enrolment ([Apple fee waivers](https://developer.apple.com/help/account/membership/fee-waivers/)) |
| Bonus | **No 12-tester / 14-day closed test** before production ([BETA_TESTING.md § 4c](BETA_TESTING.md#4c-google-play-closed-testing)) | The seller name shown on the App Store is the trust |

The volunteer developer is then invited into those accounts (Play Console →
*Users and permissions*; App Store Connect → *Users and Access*, role *App
Manager* or *Developer*). The trust keeps ownership, even if volunteers change.

**If the app is published from someone else's account**, you need:

* a signed **permission letter** from the trust ([template in section 6](#6-permission-letter-from-the-trust-template)) —
  attach it in App Store Connect (*App Review Information → Attachment*) and
  keep it ready for any Play policy question;
* **no "Official"** in the store name or subtitle.

**Rights to each kirtan and shastra.** The app lets devotees **download**
kirtans and PDFs for offline use. Before uploading a recording or a scripture
edition, make sure the trust has the right to share it that way (ask the
singer, the publisher or the mandir that made it). The permission letter
should mention offline downloads.

---

## 1. Privacy policy address

Both stores require a public privacy policy **web page** (not a PDF, no
login), linked in the store and inside the app. The text is ready in
[PRIVACY_POLICY.md](PRIVACY_POLICY.md).

1. Replace every `[BRACKETED]` value (trust's legal name, privacy e-mail,
   grievance officer, retention months) and have a trustee approve it.
2. Publish it as a normal web page — best on the temple website, e.g.
   `https://<temple-website>/privacy` (Google Sites is a free alternative).
   Gujarati and Hindi versions on the same page are welcome.
3. Firestore → `config` → `app` → field **`privacyPolicyUrl`** (string) = that
   address. *Settings → Privacy policy* and the donation form then open it.
   (Until it is set, the app opens the copy on GitHub.)
4. Play Console → **App content → Privacy policy** → paste the address.
5. App Store Connect → your app → **App Privacy → Privacy Policy URL** → paste
   it; also in TestFlight → **Test Information**.

Use the **same address** everywhere.

---

## 2. Store listing

| Field | Suggested text / rule |
|---|---|
| **App name** (both, max 30) | `Jetalpur Dham` — add "Official" only when published from the trust's own account. |
| **Subtitle** (App Store, max 30) | `Kirtan, Darshan & Utsav` |
| **Short description** (Play, max 80) | `Kirtan, prasadi places, 360° darshan, shastras and utsav news of Jetalpur Dham.` |
| **Description** (both) | Start from the feature list in the [README](../README.md#features): kirtans with offline download and lock-screen playback, prasadi places with mahima and 360° darshan, Avsar photo gallery, shastra library, utsav news with notifications, donation details, English/ગુજરાતી/हिन्दी. Describe only what the app really does. Avoid "for kids" or "for all ages" (see 3.5). |
| **Keywords** (App Store, max 100) | `Swaminarayan,kirtan,darshan,Vachanamrut,Shikshapatri,mandir,bhajan,utsav,satsang,Ahmedabad,Gujarat` |
| **Category** | Play: **Lifestyle** (or *Books & Reference*). App Store: **Lifestyle**, secondary *Reference* or *Music*. |
| **Contact** | The temple's official e-mail (required), website, phone (optional). |
| **Price** | Free. No in-app purchases. |
| **Languages** | English listing first; add Gujarati and Hindi translations of the listing where the console offers those languages. |

**Graphics**

* **Play:** app icon 512 × 512 PNG (from `assets/icons/app_icon.png`),
  **feature graphic 1024 × 500**, and 2–8 phone screenshots.
* **App Store:** iPhone screenshots — at least one for *iPhone with Dynamic
  Island (medium display)*, i.e. **1206 × 2622** or **1179 × 2556** pixels (an
  iPhone 15, 16 or 17, or the same model in the Simulator); App Store Connect
  scales them for other iPhones and shows which sizes are still missing. No
  iPad screenshots are needed: the app is iPhone-only.
* Use screenshots of the **real app with real content** (Home, Kirtan player,
  Prasadi map, a 360° view, Avsar photos, a shastra, Utsav). The demo build's
  placeholder pictures must not appear in the store.

---

## 3. Google Play — App content

Play Console → your app → **App content** (under *Policy*; use the search box
at the top if you cannot find it). Answer every item Play lists.

### 3.1 Privacy policy
The address from section 1.

### 3.2 App access
**All functionality is available without any special access** — there is no
login. (Optional: paste the reviewer notes from section 5.)

### 3.3 Ads
**No, my app does not contain ads.**

### 3.4 Content rating
Start the questionnaire, enter the temple e-mail, choose the category that
fits best (a reference / education or "other" app — not a game, not social).
Answer **No** to violence, fear, sexual content, bad language, drugs, alcohol,
gambling and crude humour; **No** to users chatting or sharing content with
each other, sharing the user's location, and buying digital goods.
Expected result: **Everyone / 3+** (IARC).

### 3.5 Target audience and content
* Age groups: **13–15, 16–17 and 18 and over**. Do **not** tick any age under
  13.
* *Could your store listing unintentionally appeal to children?* **No.**

Why: choosing an under-13 group brings in Google's *Families* rules (extra
limits on SDKs and data). Elderly and young devotees can of course use the
app — this answer is about who it is *designed for*, and the donation form is
meant for adults. Keep the listing free of cartoon characters or "for kids"
wording.

### 3.6 Data safety

**Overview questions**

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (all traffic to Firebase uses HTTPS) |
| Which account creation methods does your app support? | **My app does not allow users to create an account** |
| Do you provide a way for users to request that their data is deleted? | **Yes** — by e-mail to the privacy address in the privacy policy |

**Data types** — everything below is **collected**, **not shared**, **not
processed ephemerally**. (Google Firebase is the trust's *service provider*;
sending data to a service provider is not "sharing" in Play's terms.)

| Category → data type | Where it comes from | Required or optional | Purpose |
|---|---|---|---|
| Personal info → **Name** | Donation details form | Optional | App functionality |
| Personal info → **Phone number** | Donation details form | Optional | App functionality |
| Personal info → **Email address** | Donation details form (optional field) | Optional | App functionality |
| Financial info → **Other financial info** | Form: amount, payment method, transaction / UTR no. | Optional | App functionality |
| App activity → **Other user-generated content** | Form: the optional message | Optional | App functionality |
| App info and performance → **Crash logs** | Firebase Crashlytics | Optional (*Settings → Share crash reports*) | Analytics (finding and fixing crashes) |
| App info and performance → **Diagnostics** | Crashlytics (device model, OS version, app version); app version, platform and language sent with the form | Optional | Analytics |
| Device or other IDs → **Device or other IDs** | Firebase Cloud Messaging token / Firebase installation ID (notifications), Crashlytics installation ID | Required | App functionality (delivering notifications); Analytics (grouping crash reports) |

**Not collected:** location (the map does not use the phone's location),
photos and files (saving a photo only writes to the phone), contacts, audio,
web history, advertising ID, payment card or bank details of the devotee
(payments happen in the devotee's own UPI or bank app).

### 3.7 Advertising ID
*Does your app use advertising ID?* **No.** The app contains no advertising or
analytics SDK (Google Analytics was removed).
**Check before answering:** Play Console → *Test and release → App bundle
explorer* → your latest version → the permissions list must **not** contain
`com.google.android.gms.permission.AD_ID`. (Developers can also run
`bundletool dump manifest --bundle app-release.aab`.) If it ever appears, a
library added it — find and remove that library, or answer **Yes** and update
the Data safety form.

### 3.8 Foreground service permissions
The app uses a **media playback** foreground service so kirtans keep playing
with the screen locked. Play requires this declaration before the first
release:

1. **App content → Foreground service permissions → Start.**
2. Tick **Media playback**.
3. Description (copy):

   > Jetalpur Dham plays devotional kirtans (audio) that the user starts by
   > tapping Play. A media-playback foreground service keeps the kirtan
   > playing when the screen is locked or the user switches to another app,
   > and shows the standard media notification and lock-screen controls
   > (play/pause, previous, next). The service is in the foreground only
   > while a kirtan is playing; pausing or stopping playback ends it.

4. *What happens if this task is interrupted or deferred?* — "The kirtan the
   user is listening to would stop as soon as the screen locks or they switch
   apps."
5. **Video:** a short (about 30 seconds) screen recording: open a kirtan →
   Play → lock the phone → the lock-screen controls → playback continues.
   Upload it to YouTube as *Unlisted* (or Google Drive, "anyone with the
   link") and paste the link.

### 3.9 Other declarations Play may show

| Declaration | Answer |
|---|---|
| Government apps | **No** — the app is not made by or for a government. |
| Financial features | **My app doesn't provide any of these financial features.** It only shows the trust's UPI and bank details; payments happen in the devotee's own UPI / bank app. |
| Health apps | **My app does not have any health features.** |
| News apps | **No** — utsav announcements are not a news publication. |

### 3.10 Donations on Android (Payments policy)
Google Play's billing system **must not** be used for *tax-exempt donations*,
so showing the trust's UPI and bank details on Android is allowed — **as long
as the trust is a registered charitable / religious trust**. Before
submitting:

* Keep the trust's registration certificate (Public Trust registration number,
  and 12AB / 80G if valid) ready for a Play question.
* Show that information in `config/donation.note` **only if it is confirmed**
  (see [ADMIN_GUIDE.md § 8](ADMIN_GUIDE.md#8-update-donation-details--દાનની-વિગતો)).
* Keep offerings purely voluntary — never tie a donation to any app content or
  feature.

---

## 4. App Store (iOS)

### 4.1 Donations on iPhone — guideline 3.2.2(iv) ⚠

Apple's rule (App Review Guideline 3.2.2(iv)) does not allow:

> *"Unless you are an approved nonprofit or otherwise permitted under Section
> 3.2.1 (vi) above, collecting funds within the app for charities and
> fundraisers. Apps that seek to raise money for such causes must be free on
> the App Store and may only collect funds outside of the app, such as via
> Safari or SMS."*

The exception (3.2.1(vi)) is for **Apple-approved nonprofits** that offer
**Apple Pay** for donations inside the app. That route does not fit UPI and
bank transfers, so for now the iPhone app must not take donations inside the
app. Reviewers treat a UPI QR code, a copyable UPI ID or bank account, or a
form asking for the amount and transaction number as "collecting funds within
the app".

**Compliant design for the iPhone app** (Android keeps the full donation
screen):

* The Donate screen shows a short line of seva text and one button —
  **"Donate on the temple website"** — that opens the temple's donation web
  page in **Safari**. That web page shows the UPI QR, the bank details and the
  receipt / 80G information.
* The **Call, WhatsApp and E-mail** buttons can stay.
* No UPI QR, UPI ID, bank details, *Save QR* or amount / UTR form inside the
  iPhone app; no UPI app names in `Info.plist`, and the photo-permission text
  does not mention the donation QR.
* The trust publishes that donation page on its website (with the same
  details as `config/donation` — see
  [ADMIN_GUIDE.md § 8](ADMIN_GUIDE.md#8-update-donation-details--દાનની-વિગતો)),
  and the button opens it.
* The review notes (section 5) say that **no money is collected in the app**.

Developer: before **external** TestFlight testing or App Store submission,
open the Donate screen in an iPhone build and confirm it matches the list
above. When this guide was written, the iPhone app still showed the same UPI
QR, bank details and form as Android — if yours still does, change the code
first. (Internal TestFlight builds are not reviewed by Apple, so they can be
used meanwhile.)

If the trust later becomes an Apple-approved nonprofit with Apple Pay, this
can be revisited.

### 4.2 App Privacy ("nutrition label")
App Store Connect → your app → **App Privacy → Get Started**.

* *Do you or your third-party partners collect data from this app?* **Yes.**
* For every data type: **Tracking: No** (the app never links data with other
  companies' data for advertising, and shows no tracking prompt).

| Data type | Purpose | Linked to the user? |
|---|---|---|
| Diagnostics → **Crash Data** | App Functionality | No |
| Identifiers → **Device ID** (notification token, Crashlytics installation ID) | App Functionality | No |

**Only if the iPhone app still contains the donation details form** (which
section 4.1 advises against), also declare: Contact Info → **Name**, **Phone
Number**, **Email Address**; Financial Info → **Other Financial Info**; User
Content → **Other User Content** — purpose **App Functionality**, **linked**
to the user, not used for tracking.

**Payment Info** is **not** collected: payments happen outside the app.

### 4.3 Age rating
App Store Connect → **App Information → Age Rating → Edit** and answer
Apple's questionnaire: **None / No** for every content item (violence, mature
or suggestive themes, profanity, horror, medical, alcohol / drugs, gambling,
contests); **No** for user-generated content, messaging and chat, unrestricted
web access (links open in Safari, not inside the app) and advertising; and
**not** made for the Kids category. Expected result: **4+**. (Religious
content is not a rating factor.)

### 4.4 Other App Store Connect fields

| Field | Answer |
|---|---|
| **Export compliance** | Already answered in the app (`ITSAppUsesNonExemptEncryption = NO`, standard HTTPS only) — no documents needed. |
| **Content rights** (*App Information*) | The app shows the temple's own content; if it is not published from the trust's account, answer that it contains third-party content **and you have the rights** (the permission letter). |
| **Price and availability** | Free; India plus the countries where devotees live (or all countries). |
| **App Review Information** | Contact name, phone and e-mail of the developer; **Sign-in required: No**; *Notes* = section 5; *Attachment* = the permission letter (if needed). |
| **Version release** | *Manually release* the first version, so the temple can announce it. |

---

## 5. Notes for the app reviewers (template)

Paste into App Store Connect (*App Review Information → Notes*) and, if Play
asks, into *App access → instructions*. Replace the `[brackets]`.

```text
Jetalpur Dham is the app of Shree Swaminarayan Mandir, Jetalpur Dham (Gujarat,
India), published by [TRUST LEGAL NAME]. It offers devotional kirtans, the
sacred places of the temple with 360° darshan, a scripture library, photo
albums of temple festivals and festival announcements.

- No login or account is needed. Every feature is available right away.
- Please try: Kirtan tab -> any category -> play a kirtan (it keeps playing
  with the screen locked, with lock-screen controls); Prasadi tab -> a place ->
  360° darshan; Shastra tab -> open a book; Home -> Avsar 200 photos;
  Utsav tab -> an event. The language button at the top right switches between
  English, Gujarati and Hindi.
- Donations: the app does not collect or process any money.
  [iOS] The Donate screen only opens the temple's website in Safari, where
  devotees can give by bank transfer or UPI.
  [Android] The Donate screen shows the trust's UPI and bank details; the
  devotee pays in their own UPI or bank app, directly to the trust's bank
  account. [TRUST LEGAL NAME] is a registered public charitable trust
  ([registration no.], [12AB / 80G if applicable]).
- Content: the kirtan recordings, murti photographs and texts belong to
  [TRUST LEGAL NAME]. [If not published from the trust's account: A signed
  permission letter from the trust is attached.]
- All content is live from the temple's server and is added by temple staff;
  some categories may still be growing at the time of review. This is the
  production app — the separate demo build with sample content is used only
  for internal previews and is not submitted.
- Push notifications are used only for temple festival and katha
  announcements in the user's chosen language.
- Contact during review: [NAME], [PHONE], [E-MAIL].
```

---

## 6. Permission letter from the trust (template)

Print on the **trust's letterhead**, sign by an authorised trustee, add the
trust's stamp, scan as PDF.

```text
[Date]

To: Apple Inc. (App Store Review) / Google LLC (Google Play)

Subject: Authorization to publish the "Jetalpur Dham" mobile app

[TRUST LEGAL NAME], [registration no.], which manages Shree Swaminarayan
Mandir, Jetalpur Dham, [address], hereby confirms that:

1. The "Jetalpur Dham" app (Android package / iOS bundle ID
   com.jetalpurdham.app) is made for and with the approval of the trust.
2. [DEVELOPER NAME / ACCOUNT NAME] is authorised to publish and update the
   app on the trust's behalf on Google Play and the App Store.
3. The trust owns or has the right to use, and authorises the app to show,
   the temple's name and logo, the murti photographs, the kirtan recordings,
   the scripture texts and PDFs and the festival photographs included in the
   app — including streaming and offline download inside the app.
4. Donations shown in the app go directly to the trust's own bank account.

Contact for verification: [NAME, DESIGNATION, PHONE, E-MAIL]

[Signature]  [Name]  [Designation]  [Trust stamp]
```

---

## 7. Final checklist before you press Submit

* [ ] Publisher is the **trust's organization account**, or the permission
  letter is attached and "Official" is not in the name.
* [ ] **Privacy policy** live; the same address in Firestore, Play and App
  Store Connect.
* [ ] **Real content** in every tab — no "will be added soon" screens (Apple
  2.1 / 4.2); donation details filled in (Android) and the website donation
  page live (iPhone).
* [ ] iPhone Donate screen follows section 4.1.
* [ ] Build: new **build number**, Android signed with the **upload key**, Maps
  keys set, crash reports checked ([BETA_TESTING.md § 6](BETA_TESTING.md#6-check-that-crash-reports-arrive)).
* [ ] Play: privacy policy, app access, ads, content rating, target audience,
  data safety, advertising ID, **foreground service**, and the other
  declarations all show a green tick.
* [ ] Play (personal accounts only): closed test with 12+ testers for 14 days
  done and **production access granted**.
* [ ] App Store: App Privacy, age rating, screenshots, review notes, contact
  details complete.
* [ ] Beta test data deleted (`donation_requests` named TEST…, test events and
  notifications); `config/donation.notifyEmail` set to the office; App Check
  on.

---

## 8. After approval

* Put the store links in Firestore `config/app.shareUrl` (one link, e.g. the
  temple's download page or the Play link) so *Share App* works.
* Play: roll out to a **percentage** first (e.g. 20 %), watch Crashlytics for
  a day or two, then go to 100 %. App Store: you may choose **phased
  release**.
* Reply to store reviews politely; collect suggestions for the next version.
* For every update: raise the version and build number
  ([FIREBASE_SETUP.md § 15](FIREBASE_SETUP.md#15-build-and-publish)) and
  re-check sections 3.6 and 4.2 if the app now collects anything new.

Jay Shree Swaminarayan 🙏
