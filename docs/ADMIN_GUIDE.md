# Jetalpur Dham App — Admin Guide
## એડમિન માર્ગદર્શિકા (મંદિર સેવકો માટે)

Jay Shree Swaminarayan! 🙏

Everything devotees see in the app — kirtans, Avsar photos, shastras, utsav
news, prasadi places, donation details, darshan timings — is managed from the
**Firebase console** in a web browser. There is no separate admin panel and no
need to update the app: **changes appear on every phone within seconds**, and
phones that are offline get them the next time they connect.

**Contents**

* [Before you start — શરૂઆત પહેલાં](#before-you-start--શરૂઆત-પહેલાં)
* [Text in three languages — ત્રણ ભાષામાં લખાણ](#text-in-three-languages--ત્રણ-ભાષામાં-લખાણ)
* [1. Add kirtans — કીર્તન ઉમેરો](#1-add-kirtans--કીર્તન-ઉમેરો)
* [2. Feature a kirtan on Home — કીર્તન હોમ પર બતાવો](#2-feature-a-kirtan-on-home--કીર્તન-હોમ-પર-બતાવો)
* [3. Upload Avsar 200 photos — અવસર ૨૦૦ના ફોટા](#3-upload-avsar-200-photos--અવસર-૨૦૦ના-ફોટા)
* [4. Add a new photo album — નવું આલ્બમ](#4-add-a-new-photo-album--નવું-આલ્બમ)
* [5. Add a shastra PDF — શાસ્ત્ર ઉમેરો](#5-add-a-shastra-pdf--શાસ્ત્ર-ઉમેરો)
* [6. Add an utsav / katha and notify devotees — ઉત્સવ / કથા અને નોટિફિકેશન](#6-add-an-utsav--katha-and-notify-devotees--ઉત્સવ--કથા-અને-નોટિફિકેશન)
* [7. Send any notification — કોઈ પણ સૂચના મોકલો](#7-send-any-notification--કોઈ-પણ-સૂચના-મોકલો)
* [8. Update donation details — દાનની વિગતો](#8-update-donation-details--દાનની-વિગતો)
* [9. View donation requests — દાનની વિનંતીઓ જુઓ](#9-view-donation-requests--દાનની-વિનંતીઓ-જુઓ)
* [10. Edit a prasadi place and its mahima — પ્રસાદીનું સ્થાન અને મહિમા](#10-edit-a-prasadi-place-and-its-mahima--પ્રસાદીનું-સ્થાન-અને-મહિમા)
* [11. Add 360° darshan photos — ૩૬૦° દર્શન](#11-add-360-darshan-photos--૩૬૦-દર્શન)
* [12. Change darshan timings — દર્શનનો સમય બદલો](#12-change-darshan-timings--દર્શનનો-સમય-બદલો)
* [13. Hide something — સામગ્રી છુપાવો](#13-hide-something--સામગ્રી-છુપાવો)
* [14. Replace the murti image — મૂર્તિનો ફોટો બદલો](#14-replace-the-murti-image--મૂર્તિનો-ફોટો-બદલો)
* [15. Temple details and links — મંદિરની વિગતો](#15-temple-details-and-links--મંદિરની-વિગતો)
* [Before-launch checklist — લૉન્ચ પહેલાંની ચકાસણી](#before-launch-checklist--લૉન્ચ-પહેલાંની-ચકાસણી)
* [Help — મુશ્કેલી હોય તો](#help--મુશ્કેલી-હોય-તો)

---

## Before you start — શરૂઆત પહેલાં

1. Open <https://console.firebase.google.com> and sign in with the Google
   account the trust has added to the project.
2. Click the **Jetalpur Dham** project.
3. You will use two places from the left menu:

   | Menu | What is there |
   |---|---|
   | **Firestore Database** | All text and settings ("documents" inside "collections") |
   | **Storage** | All files — MP3 kirtans, photos, PDFs, banners |

**Editing a field in Firestore:** click a collection (left column) → click a
document (middle column) → move the mouse over a field (right column) → click
the ✏ pencil → change the value → **Update**. To add a field click
**+ Add field**, type the field name exactly as shown in this guide, choose the
**type**, enter the value and click **Add**.

**Creating a folder in Storage:** a folder only exists once it holds a file,
so the very first time the `kirtans`, `gallery` or `books` folder (or a
category folder inside it) is not there yet. Click the **folder icon with a +**
(*Create folder*) at the top of the file list, type the name exactly as
written in this guide (lowercase, dashes instead of spaces, e.g. `kirtans`,
then inside it `aarti-stuti`) and open the new folder before uploading.

**Field types** you will meet:

| Type | Example |
|---|---|
| string | `Jay Sadguru Swami` |
| number | `3` |
| boolean | `true` / `false` |
| map | a group of named fields, e.g. `en`, `gu`, `hi` |
| array | a list, e.g. several photo paths |
| timestamp | a date and time (the picker uses your computer's time — set it in India time) |
| geopoint | a map position: latitude, longitude |

**Golden rules**

* Type field names exactly (they are case-sensitive): `isActive`, not `isactive`.
* `order` decides the position in lists: 1 comes first. Items without `order` come last.
* To hide something, set `isActive` to `false` instead of deleting it.
* Only upload files you have permission to use (temple photos, licensed recordings).
* Never change the fields marked *automatic* — the system fills them.

## Text in three languages — ત્રણ ભાષામાં લખાણ

Any text field (titles, descriptions, mahima…) can be written in two ways:

**One text for everyone** — type **string**:

```
title  (string)   Avsar 200
```

**Separate text per language** — type **map** with fields `en`, `gu`, `hi`
(each a **string**):

```
title  (map)
   en  (string)   Holi Utsav
   gu  (string)   હોળી ઉત્સવ
   hi  (string)   होली उत्सव
```

If a language is missing, the app shows English, then Gujarati, then Hindi —
so it is fine to start with only `gu` and add the others later. Devotees
search in any of the three scripts.

---

## 1. Add kirtans — કીર્તન ઉમેરો

You only upload the MP3 file; the kirtan appears in the app by itself.

1. **Prepare the audio.** MP3 at **128 kbps** (96 kbps is enough for dhun and
   spoken katha). This starts playing instantly and saves devotees' data. In
   the free program *Audacity*: **File → Export → MP3**, quality *128 kbps*.
2. **Name the file well** — the name becomes the title and the number becomes
   the position:
   `01 - Jay Sadguru Swami.mp3`, `02 - Sant Samagam Kije.mp3`.
   (Underscores and dashes become spaces; Gujarati file names work too.)
3. **Storage → `kirtans` → the category folder** (for example `aarti-stuti`).
   Click **Upload file** and select one or many files (you can select 100 at
   once).
4. Wait about a minute. **Firestore → `kirtans`** now has a document for each
   file with the title, category, size and audio link filled in.
5. **Polish it** (optional but recommended): open the new document and

   | Field | Type | Example |
   |---|---|---|
   | `title` | map | `en` Jay Sadguru Swami · `gu` જય સદ્‌ગુરુ સ્વામી · `hi` जय सद्गुरु स्वामी |
   | `poet` | map / string | `en` Muktanand Swami · `gu` મુક્તાનંદ સ્વામી |
   | `singer` | map / string | the singer's name |
   | `lyrics` | map / string | the full pad (shown in the player) |
   | `durationSec` | number | `312` (shown before playing; optional) |
   | `coverUrl` | string | an image path, e.g. `kirtans/covers/aarti.jpg` (lock-screen artwork) |
   | `order` | number | position inside the category |

Your edits are never overwritten. Uploading a **better recording with the same
file name** only replaces the audio. **Deleting the file** in Storage removes
the kirtan from the app.

*Automatic fields — do not edit:* `audioUrl`, `storagePath`, `sizeBytes`,
`contentType`, `createdAt`, `updatedAt`.

**Kirtan categories (folders)**

| Folder / id | English | ગુજરાતી | हिन्दी |
|---|---|---|---|
| `aarti-stuti` | Aarti & Stuti | આરતી અને સ્તુતિ | आरती और स्तुति |
| `prabhatiya` | Prabhatiya (Morning Hymns) | પ્રભાતિયાં | प्रभातिया |
| `chesta` | Chesta Pad | ચેષ્ટાનાં પદ | चेष्टा के पद |
| `thal` | Thal | થાળ | थाल |
| `dhun` | Dhun | ધૂન | धुन |
| `utsav` | Utsav Kirtans | ઉત્સવનાં કીર્તન | उत्सव कीर्तन |
| `bhajan` | Bhajan & Pad | ભજન અને પદ | भजन और पद |
| `ashtak-chhand` | Ashtak & Chhand | અષ્ટક અને છંદ | अष्टक और छंद |

**New category:** Firestore → `kirtan_categories` → **+ Add document** →
Document ID e.g. `katha` (lowercase, dashes, no spaces) → fields `name` (map
en/gu/hi), `order` (number), `isActive` (boolean `true`). Then upload files to
the Storage folder `kirtans/katha/`. (You may also make poet-wise categories
such as `premanand-swami`; each kirtan belongs to one category, and devotees
can always find kirtans by poet with search.)

## 2. Feature a kirtan on Home — કીર્તન હોમ પર બતાવો

Open the kirtan in **Firestore → `kirtans`** → **+ Add field** `isFeatured`,
type **boolean**, value `true`. Featured kirtans appear on the Home screen in
`order`. Set it back to `false` to remove it from Home.

## 3. Upload Avsar 200 photos — અવસર ૨૦૦ના ફોટા

1. **Prepare the photos:** JPEG, about **2048 pixels** on the long side,
   quality **~80 %** (each photo then is about 0.4–0.8 MB and opens quickly).
   On Windows: select photos → right-click → *Resize pictures* (PowerToys) or
   use any photo tool's *Export*. iPhone photos must be **JPEG, not HEIC**
   (iPhone *Settings → Camera → Formats → Most Compatible*, or export as JPEG);
   HEIC files are skipped.
2. **Order:** photos are shown in the order of the number in their file name.
   Camera names such as `IMG_0001.jpg` / `DSC01234.jpg` keep the camera's
   order. To choose your own order, number the files `001.jpg`, `002.jpg` …,
   or in Windows File Explorer sort the photos the way you want, select them
   all (**Ctrl+A**), press **F2**, type `Avsar` and press **Enter** (Windows
   names them `Avsar (1).jpg`, `Avsar (2).jpg` …). Photos without a number
   come after numbered ones.
   You can always change a photo's `order` (number) in Firestore later.
3. **Storage → `gallery` → `avsar-200`** → **Upload file** → select all photos.
4. Within a minute each photo appears in the app's **Avsar 200** album,
   `photoCount` goes up and the first photo becomes the album cover.

**Change the cover:** Firestore → `albums` → `avsar-200` → `photos` → open the
photo you like → copy its `url` value → paste it into the album's `coverUrl`.

**Caption a photo:** in that photo document add `caption` (map en/gu/hi).

**Remove a photo:** delete the file in Storage — the app updates by itself.

*Automatic fields — do not edit:* `photoCount`, and in photos `url`,
`thumbUrl`, `storagePath`, `sizeBytes`, `createdAt`.

## 4. Add a new photo album — નવું આલ્બમ

**Fastest way:** Storage → `gallery` → **Create folder** with a short id such as
`janmashtami-2026` → upload photos into it. The album is created automatically
(titled "Janmashtami 2026"). Then in **Firestore → `albums` → `janmashtami-2026`**
set:

| Field | Type | Notes |
|---|---|---|
| `title` | map | en / gu / hi |
| `description` | map | a few lines about the utsav |
| `eventDate` | timestamp | the date of the utsav (albums are sorted by it) |
| `isFeatured` | boolean | `true` highlights the album |
| `order` | number | optional manual position |
| `isActive` | boolean | `false` hides the album |

* To show this album on the Home screen instead of Avsar 200, set
  **`config/app` → `featuredAlbumId`** = `janmashtami-2026`.
* To add a **"View photos"** button to an utsav, set that event's `albumId` to
  the album id.

## 5. Add a shastra PDF — શાસ્ત્ર ઉમેરો

1. **Compress the PDF** first (aim for under 30 MB): use *ilovepdf.com →
   Compress PDF* (recommended level) or Adobe Acrobat *Reduce file size*.
   Text PDFs are better than scanned photos (smaller and sharper).
2. **Storage → `books` → the category folder** → upload the PDF, e.g.
   `books/core/Vachanamrut.pdf`.
3. A document appears in **Firestore → `books`** (language `gu` by default).
   Open it and complete:

   | Field | Type | Example |
   |---|---|---|
   | `title` | map | `en` Vachanamrut · `gu` વચનામૃત · `hi` वचनामृत |
   | `author` | map | `gu` ભગવાન શ્રી સ્વામિનારાયણ |
   | `description` | map | 2–3 lines |
   | `language` | string | language of the PDF: `gu`, `hi`, `en` or `sa` (Sanskrit) |
   | `coverUrl` | string | upload a cover image to `books/covers/` and paste its path |
   | `pageCount` | number | optional |
   | `isFeatured` | boolean | `true` to highlight it |
   | `order` | number | position in the category |

**Book categories (folders)**

| Folder / id | English | ગુજરાતી |
|---|---|---|
| `core` | Core Scriptures | મુખ્ય શાસ્ત્રો |
| `biography` | Life of Shreeji Maharaj | શ્રીજી મહારાજનું ચરિત્ર |
| `poetry` | Kavya & Kirtan Granths | કાવ્ય અને કીર્તન ગ્રંથો |
| `philosophy` | Philosophy | તત્ત્વજ્ઞાન |
| `other` | Commentaries & Other Granths | ભાષ્ય અને અન્ય ગ્રંથો |

**Suggested shastras** (titles ready to copy; upload only editions the temple
is permitted to share):

| English | ગુજરાતી | हिन्दी | Folder | Language of original |
|---|---|---|---|---|
| Vachanamrut | વચનામૃત | वचनामृत | `core` | `gu` |
| Shikshapatri | શિક્ષાપત્રી | शिक्षापत्री | `core` | `sa` |
| Desh Vibhag no Lekh | દેશવિભાગનો લેખ | देशविभाग का लेख | `core` | `gu` |
| Shree Satsangi Jivan | શ્રી સત્સંગિજીવન | श्री सत्संगिजीवन | `biography` | `sa` |
| Bhaktachintamani | ભક્તચિંતામણિ | भक्तचिंतामणि | `biography` | `gu` |
| Shree Harililamrut | શ્રી હરિલીલામૃત | श्री हरिलीलामृत | `biography` | `gu` |
| Shree Harilila Kalpataru | શ્રી હરિલીલાકલ્પતરુ | श्री हरिलीलाकल्पतरु | `biography` | `sa` |
| Shree Satsangi Bhushan | શ્રી સત્સંગિભૂષણ | श्री सत्संगिभूषण | `biography` | `sa` |
| Shree Haricharitramrut Sagar | શ્રી હરિચરિત્રામૃતસાગર | श्री हरिचरित्रामृतसागर | `biography` | `hi` |
| Shree Hari Digvijay | શ્રી હરિદિગ્વિજય | श्री हरिदिग्विजय | `philosophy` | `sa` |
| Purushottam Prakash | પુરુષોત્તમ પ્રકાશ | पुरुषोत्तम प्रकाश | `poetry` | `gu` |
| Yamdand | યમદંડ | यमदंड | `poetry` | `gu` |
| Nishkulanand Kavya | નિષ્કુળાનંદ કાવ્ય | निष्कुलानंद काव्य | `poetry` | `gu` |
| Brahmanand Kavya | બ્રહ્માનંદ કાવ્ય | ब्रह्मानंद काव्य | `poetry` | `gu` |
| Muktanand Kavya | મુક્તાનંદ કાવ્ય | मुक्तानंद काव्य | `poetry` | `gu` |
| Shikshapatri Arthadipika Bhashya | શિક્ષાપત્રી અર્થદીપિકા ભાષ્ય | शिक्षापत्री अर्थदीपिका भाष्य | `other` | `sa` |

*Swamini Vato* is read differently across the Sampraday — please ask the
mahant before adding it.

## 6. Add an utsav / katha and notify devotees — ઉત્સવ / કથા અને નોટિફિકેશન

**Step A — banner (optional but beautiful).** Make a **16:9** image,
**1600 × 900** pixels, JPEG. Storage → `events` → upload, e.g.
`events/holi-2027.jpg`. Copy its path: `events/holi-2027.jpg` (you may also
paste the `gs://…` link or the download link).

**Step B — the event.** Firestore → `events` → **+ Add document** → Document ID
e.g. `holi-2027` (or *Auto-ID*) → add these fields:

| Field | Type | Example / notes |
|---|---|---|
| `title` | map | `en` Holi Utsav · `gu` હોળી ઉત્સવ · `hi` होली उत्सव |
| `shortDescription` | map | one line — this is also the notification text |
| `description` | map | full details: programme, timings, prasad… |
| `location` | map | `en` Jetalpur Dham |
| `bannerUrl` | string | `events/holi-2027.jpg` |
| `startAt` | timestamp | ⚠ required — start date & time |
| `endAt` | timestamp | optional, for a multi-day utsav |
| `type` | string | `utsav`, `katha`, `announcement` or `other` |
| `albumId` | string | optional, e.g. `holi-2027` → "View photos" |
| `liveUrl` | string | optional YouTube live link → "Watch live" |
| `isActive` | boolean | `true` |
| `sendNotification` | boolean | **`false` for now** |

Save, then check the event in the app (**Utsav** tab). Upcoming events are
listed first; after its end date an event moves to **Past events**
automatically.

**Step C — notify everyone.** When the event looks right, change
`sendNotification` to **`true`**. Within a minute every devotee receives a
notification **in their own app language**, with the banner picture (Android)
— tapping it opens this event. The event then shows:

| Field (automatic) | Meaning |
|---|---|
| `notifiedAt` | when it was sent — it is sent **only once** |
| `notificationStatus` | `sent`, or `error` |
| `notificationError` | the reason, if something went wrong |

Editing the event later does **not** send it again. To send a reminder later,
delete the `notifiedAt` field (it is then sent once more), or use section 7.

> Tip: set `sendNotification` last. If it is `true` while the title is still
> empty, nothing is sent until a title is added.

## 7. Send any notification — કોઈ પણ સૂચના મોકલો

For quick messages ("Katha tonight at 8 PM", "Live darshan now"):

Firestore → **`notifications`** → **+ Add document** (*Auto-ID*) → fields:

| Field | Type | Notes |
|---|---|---|
| `title` | map / string | required |
| `body` | map / string | the message |
| `imageUrl` | string | optional picture (Storage path or https link) |
| `route` | string | optional — which screen opens on tap (table below) |
| `eventId` | string | optional — the event's **Document ID** (e.g. `holi-2027`); opens that event, and fills title/text/banner from it if you left them empty. If no event has that id, the message is still sent and opens the Utsav list. |

Do **not** add a `status` field — the system writes `status` (`sent` or
`error`), `sentAt`, `error`, `successCount` and `failureCount` back into the
document after sending.

**Screens you can open (`route`)**

| Route | Opens |
|---|---|
| `/home` | Home |
| `/events` | Utsav list (default) |
| `/events/<eventId>` | One event, e.g. `/events/holi-2027` |
| `/kirtan` | Kirtans |
| `/kirtan/downloads` | Downloaded kirtans |
| `/places` | Prasadi places map |
| `/places/<placeId>` | One place, e.g. `/places/dev-sarovar` |
| `/library` | Shastra library |
| `/library/<bookId>` | One book |
| `/home/gallery` | All photo albums |
| `/home/gallery/<albumId>` | One album, e.g. `/home/gallery/avsar-200` |
| `/home/donate` | Donation |
| `/home/about` | About the temple & darshan timings |

You can also use **Messaging → New campaign** in the console (choose
*Topic* `lang_gu`, `lang_en` or `lang_hi`; under *Additional options → Custom
data* add key `route` with one of the routes above).

## 8. Update donation details — દાનની વિગતો

Firestore → `config` → **`donation`**. Get every number confirmed in writing by
the trust and test with a ₹1 UPI payment before switching it on.

| Field | Type | Example / notes |
|---|---|---|
| `enabled` | boolean | `true` shows the payment details (while `false` the app says "available soon") |
| `upiId` | string | e.g. `jetalpurmandir@sbi` |
| `payeeName` | string | name shown in the UPI app, e.g. `Shree Swaminarayan Mandir Jetalpur` |
| `qrImageUrl` | string | upload the bank's official QR to Storage `config/` (e.g. `config/upi-qr.png`) and paste the path. If empty, the app makes a QR from `upiId`. |
| `bank` | map | `accountName`, `accountNumber`, `ifsc`, `bankName`, `branch`, `accountType` (e.g. Savings) — all strings |
| `contactPhone` | string | `+91 98765 43210` |
| `contactWhatsapp` | string | digits with country code, no `+`: `919876543210` |
| `contactEmail` | string | the office e-mail |
| `notifyEmail` | string | where new donation forms are e-mailed (see the setup guide) — use an official address, as the app can read it |
| `title`, `message` | map | heading and line shown on the donation screen |
| `note` | map | small print, e.g. the trust's registration number and receipt / 80G tax-exemption information (only if confirmed — Google Play allows donation details in the app for registered, tax-exempt trusts) |
| `purposes` | array of maps | choices in the form: General seva, Thal / Annakut, Utsav seva, Gau seva, Mandir maintenance, Sadhu/Brahmin bhojan (each `en`/`gu`/`hi`) |

**iPhone:** Apple does not allow donation payment details (UPI QR, bank
account, amount form) inside iPhone apps unless the trust is an
Apple-approved nonprofit — see
[STORE_SUBMISSION.md § 4.1](STORE_SUBMISSION.md#4-app-store-ios). Before the
App Store release, the iPhone app must instead send devotees to a **donation
page on the temple website** (the developer sets this up). Please prepare that
page, and whenever you change the UPI ID, QR or bank details here, change them
on that web page too.

## 9. View donation requests — દાનની વિનંતીઓ જુઓ

When a devotee taps **Contact Now** and submits the form, a document appears in
**Firestore → `donation_requests`** with `name`, `phone`, `email`, `amount`,
`purpose`, `method` (`upi`, `bank`, `cash`, `cheque`, `other`),
`transactionRef` (UTR / transaction no.), `message`, `language`, `createdAt`.

* To see the newest first, click the filter (funnel) button above the
  documents and sort by `createdAt`, descending.
* Verify the payment in the bank statement, then call/WhatsApp the devotee and
  send the receipt. You may add your own fields to keep track, e.g.
  `status` = `done`, `receiptNo` = `R-1023`, `handledBy` = your name.
* With `notifyEmail` set (and the e-mail extension installed) the office also
  gets an e-mail for every new form.
* These documents contain personal details — do not share screenshots
  outside the office.

**How long to keep them (privacy rule).** The privacy policy promises devotees
that their details are deleted from the app **[12] months after the receipt
is issued** (use the same number as in the published policy). Once a month,
sort by `createdAt` and **delete** the requests that are older than that and
already handled. Records the trust must keep for accounts or 80G receipts
belong in the trust's own books, not in Firestore.

**If a devotee asks** to see, correct or delete the details they sent (by
e-mail to the privacy address, phone or in person), find their request(s) by
name or phone number, do what they ask **within 30 days**, and reply to
confirm.

**During the beta test**, testers send practice forms with names starting
with **TEST** — delete them when the beta ends.

## 10. Edit a prasadi place and its mahima — પ્રસાદીનું સ્થાન અને મહિમા

Firestore → **`places`** → choose the place.

| Field | Type | Notes |
|---|---|---|
| `name` | map | |
| `shortDescription` | map | one line shown on the map card |
| `mahima` | map | the full greatness / prasang (long text) |
| `address` | map | optional |
| `category` | string | kind of place: `temple`, `yagna`, `water`, `tree`, `residence` or `other` |
| `location` | geopoint | the map pin — see below |
| `images` | array of strings | photos; upload to Storage `places/<placeId>/` and add each path, the first one is the cover |
| `panoramaUrls` | array of strings | 360° photos (section 11) |
| `streetView` | map | optional `lat`, `lng`, `heading`, `pitch` (numbers) for Google Street View |
| `order` | number | position in the list |
| `isActive` | boolean | `false` hides the place |

**⚠ The map pins are approximate.** The starter data places all nine prasadi
places within about 60 m of the mandir so the pins don't overlap. Please stand
at each place (or find it on Google Maps), get the exact position and update
`location`:

* In Google Maps (phone): long-press the exact spot → the coordinates appear at
  the top, e.g. `22.889512, 72.595634` → in the console edit `location` and
  enter latitude `22.889512` and longitude `72.595634`.

| Place id | Name | Category | Starter pin (approx.) |
|---|---|---|---|
| `nij-mandir-revati-baldevji` | Nij Mandir of Shree Revati Baldevji Harikrushna Maharaj | temple | 22.88950, 72.59560 |
| `vachanamrut-sthan` | Vachanamrut Sthan – Courtyard of Shree Baldevji Mandir | temple | 22.88962, 72.59548 |
| `gangama-no-ordo` | Gangama's Ordo (Gangama's Room) | residence | 22.88938, 72.59575 |
| `yagnashala-yagnabhumi` | Yagnashala – Yagnabhumi of Shreeji Maharaj | yagna | 22.88975, 72.59585 |
| `dev-sarovar` | Dev Sarovar (Jetalpur Lake) | water | 22.88915, 72.59595 |
| `prasadi-ni-borsali` | Prasadi Borsali (Bakul) Tree | tree | 22.88968, 72.59532 |
| `prasadi-ni-amli` | Prasadi Ambli (Tamarind) Tree | tree | 22.88922, 72.59530 |
| `prasadi-nu-shivling` | Prasadi Shivling | temple | 22.88985, 72.59560 |
| `prasadi-vastu` | Prasadi Vastu – Sacred Relics of Shreeji Maharaj | other | 22.88940, 72.59546 |

**Please have the mahima reviewed.** The starter texts were compiled carefully
from public Sampraday sources, leaving out anything that could not be
confirmed. A learned sant or trustee should read them in all three languages —
especially the **Prasadi Shivling** and the two **prasadi trees**, whose own
prasangs were not found and can be added here. The temple's own documentary
(*Jetalpurdham Prasadi sthan Darshan*) may show further places; add them with
**+ Add document** using the same fields.

**Add a new place:** `places` → **+ Add document** → id like `prasadi-vav` →
the fields above (at least `name`, `location`, `category`, `isActive`).

## 11. Add 360° darshan photos — ૩૬૦° દર્શન

The app shows full 360° photos that devotees can turn around in with a
swipe — like standing at the prasadi place.

**What kind of photo:** an **equirectangular 360° photo** — exactly twice as
wide as it is tall (**2:1**), e.g. **4096 × 2048** px (best for smooth
viewing on phones; up to 6000 × 3000), JPEG ~80 %, under 8 MB. A normal phone
"Panorama" picture is *not* 360° and will look stretched.

**How to take one**

* Best: a 360° camera (e.g. Insta360 X-series or Ricoh Theta). Place it on a
  stick at eye level in the middle of the place, step out of sight (or use
  the timer), and export the photo as a "360° photo / equirectangular JPEG".
* Some phones and camera apps have a **Photo Sphere / 360°** mode that saves
  the same format. (Google's old *Street View* app, often used for this, was
  retired by Google in 2023.)
* Take it in soft daylight, keep people out of the frame, and keep the camera
  level.

**Add it:** Storage → `places` → `<placeId>` (e.g. `places/dev-sarovar/`) →
upload `360-1.jpg` → in Firestore open the place → `panoramaUrls` (type
**array**) → add a **string** item `places/dev-sarovar/360-1.jpg`. Add more
items for more viewpoints.

**Google Street View button:** if Google Maps already has Street View at that
spot, add `streetView` (map) with `lat` and `lng` (numbers) of the viewpoint,
`heading` (0 = facing north, 90 = east, 180 = south, 270 = west) and `pitch`
(0 = straight ahead). Without it the place's own `location` is used.

## 12. Change darshan timings — દર્શનનો સમય બદલો

Firestore → `config` → **`app`** → **`darshanTimings`** (array). Each item is a
map with:

* `label` (map): `en` Mangla Aarti · `gu` મંગળા આરતી · `hi` मंगला आरती
* `time` (string): `5:30 AM` (or a range such as `5:30 AM – 12:15 PM`)

Edit a time with the ✏ pencil; add a row with **+** (choose type map); the app
shows the rows in this order.

The starter timings are from the Kalupur Mandir website (Mangla 5:30 AM,
Shangar 7:15 AM, Rajbhog 10:10 AM, Sandhya 7:15 PM, Shayan 8:45 PM; darshan
5:30 AM–12:15 PM and 3:30 PM–9:00 PM). **Please confirm them** with the mandir
and update them for seasonal or utsav changes.

## 13. Hide something — સામગ્રી છુપાવો

Every kirtan, category, album, book, place and event has **`isActive`**. Set it
to **`false`** (boolean) and it disappears from the app immediately; set it to
`true` to bring it back. If the field is missing the item is shown. Prefer
hiding to deleting — nothing is lost.

## 14. Replace the murti image — મૂર્તિનો ફોટો બદલો

The opening screen and Home show the darshan of **Shree Revati Baldevji
Harikrushna Maharaj**.

**Without an app update (recommended for daily/utsav shangar):**

1. Prepare a portrait photo (about **1440 × 1920** px, JPEG ~85 %), ideally
   the official temple photograph.
2. Storage → `config` → upload, e.g. `config/murti-2026-holi.jpg`.
3. Firestore → `config` → `app` → set **`heroImageUrl`** (string) =
   `config/murti-2026-holi.jpg`.

All phones show the new image. Clear the field to go back to the image built
into the app.

**Built-in image (developer, needs a new app release):** replace
`assets/images/murti.jpg` with the official photo (same file name, portrait,
about 1440 px wide), and for the launch splash `assets/icons/splash_logo.png`,
then rebuild the app (see the setup guide).

Use only photographs the trust has approved for publication.

## 15. Temple details and links — મંદિરની વિગતો

Firestore → `config` → **`app`**:

| Field | Type | Notes |
|---|---|---|
| `templeName`, `tagline` | map | shown on Home |
| `about` | map | temple history on "About Temple" |
| `address` | map | shown with a "Get directions" button |
| `location` | geopoint | the temple pin (22.8895, 72.5956) |
| `phone` | string | `+91 98765 43210` — the "Call" button |
| `whatsapp` | string | `919876543210` (country code, digits only) |
| `email`, `website` | string | website: `https://jetalpurdarshan.com` |
| `youtube`, `facebook`, `instagram` | string | full links (https://…) |
| `shareUrl` | string | Play Store / App Store link for "Share App" (after publishing) |
| `privacyPolicyUrl` | string | the published privacy policy page, e.g. `https://jetalpurdarshan.com/privacy` — opened by *Settings → Privacy policy* and the donation form (see [STORE_SUBMISSION.md § 1](STORE_SUBMISSION.md#1-privacy-policy-address)) |
| `featuredAlbumId` | string | album on Home, default `avsar-200` |
| `heroImageUrl` | string | section 14 |

**Send feedback:** *Settings → Send feedback* in the app opens an e-mail to
`email` (or, if there is no e-mail, a WhatsApp chat to `whatsapp`) with the
app version and phone details filled in. The item is hidden until one of the
two is set — please check this inbox regularly, especially during the beta.

`phone`, `whatsapp` and `email` start empty on purpose. The temple website
(an older copy) lists **+91 90999 39376**, **+91 93778 70630** and
**jetalpurdham9@gmail.com** — please confirm which ones the office wants
published before entering them.

---

## Before-launch checklist — લૉન્ચ પહેલાંની ચકાસણી

* [ ] Darshan and aarti timings confirmed (section 12)
* [ ] Address and PIN code confirmed — sources give both **382427** and **382426**
* [ ] Phone, WhatsApp and e-mail entered (section 15)
* [ ] All nine prasadi place pins moved to their exact spots (section 10)
* [ ] Mahima texts reviewed in English, ગુજરાતી and हिन्दी (section 10)
* [ ] Donation UPI ID, QR and bank details entered, tested with ₹1, `enabled` = `true` (section 8)
* [ ] Official murti photograph approved (section 14)
* [ ] Avsar 200 photos uploaded (section 3)
* [ ] At least a few kirtans per category and the main shastras uploaded
* [ ] Permission from the singer / publisher for every recording and shastra edition uploaded
* [ ] A test notification received on Android and iPhone (setup guide, step 13)
* [ ] Privacy policy published and `privacyPolicyUrl` set (section 15)
* [ ] `email` (or `whatsapp`) set, so devotees can *Send feedback* (section 15)
* [ ] Donation page on the temple website ready for iPhone users (section 8)
* [ ] Trust's written permission letter signed, or the app published from the
  trust's own accounts ([STORE_SUBMISSION.md](STORE_SUBMISSION.md#0-who-publishes-the-app))
* [ ] Beta test finished and test data deleted ([BETA_TESTING.md](BETA_TESTING.md#10-after-the-beta))

## Help — મુશ્કેલી હોય તો

| Problem | Solution |
|---|---|
| I uploaded a file but nothing appeared | Wait one minute. Check the folder name matches a category/album id exactly (lowercase, dashes). Kirtans must be MP3/M4A, photos JPEG/PNG/WebP (not HEIC), books PDF. |
| A title shows the file name | Edit `title` in the document (section 1 / 5). |
| Notification did not arrive | Look at the event's `notificationStatus` / `notificationError`. On the phone, notifications must be allowed and switched on in the app's Settings. |
| I sent a notification by mistake | It cannot be recalled; send a short correction with section 7. |
| Something disappeared | Check `isActive` is not `false`. Kirtans/photos/books also disappear when their file is deleted from Storage. |
| I need to undo a change | Firestore has no undo — note old values before big edits. Your developer can set up scheduled Firestore backups. |

For anything technical (new features, app updates, publishing), contact the
app developer and share [FIREBASE_SETUP.md](FIREBASE_SETUP.md). For the test
period before launch see [BETA_TESTING.md](BETA_TESTING.md); for the Play
Store and App Store forms see [STORE_SUBMISSION.md](STORE_SUBMISSION.md).

Jay Shree Swaminarayan 🙏
