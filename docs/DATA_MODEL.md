# Data model (Firestore + Storage)

This is the contract between the app, the security rules, the Cloud Functions
and the seed script. **Everything the app shows comes from here** — temple staff
manage content directly in the Firebase console; there is no separate admin panel.

## Conventions

| Convention | Meaning |
|---|---|
| `LocalizedText` | Either a plain string (shown in every language) **or** a map `{ "en": "...", "gu": "...", "hi": "..." }`. Missing languages fall back to English → Gujarati → Hindi. |
| `MediaRef` | A string that is any of: an `https://` URL, a `gs://bucket/path` URL, or a bare Storage path like `gallery/avsar-200/01.jpg`. The app resolves it. |
| `order` | Optional number. Lists sort ascending by `order`; items without `order` go last (then by date/title). |
| `isActive` | Optional boolean, default `true`. Set `false` to hide an item without deleting it. |
| Timestamps | Firestore `timestamp` type (the console's "timestamp" field type). |

The app never needs composite indexes: it reads each (small) collection and
filters/sorts on the device, so a missing field can never make an item vanish.

## Collections

### `config/app` (single document)
| Field | Type | Notes |
|---|---|---|
| `templeName`, `tagline`, `about`, `address` | LocalizedText | `about` = temple history shown on "About Temple" |
| `location` | geopoint | Temple location (Jetalpur ≈ 22.8895, 72.5956) |
| `phone`, `whatsapp`, `email`, `website` | string | `whatsapp` with country code, e.g. `919099939376` |
| `youtube`, `facebook`, `instagram` | string | Full URLs |
| `darshanTimings` | array of `{ label: LocalizedText, time: string }` | e.g. `{label: {en:"Mangla Aarti"}, time: "5:30 AM"}` |
| `heroImageUrl` | MediaRef | Optional remote home image; the bundled murti image is used when empty |
| `featuredAlbumId` | string | Album shown on Home (default `avsar-200`) |
| `shareUrl` | string | Play Store / landing page used by "Share App" |

### `config/donation` (single document)
| Field | Type | Notes |
|---|---|---|
| `enabled` | bool | `false` hides payment details and shows "available soon" |
| `title`, `message`, `note` | LocalizedText | `note` e.g. 80G tax-exemption info |
| `upiId`, `payeeName` | string | Used for "Pay with UPI app" and to generate a QR when no image is set |
| `qrImageUrl` | MediaRef | Official QR image (optional) |
| `bank` | map `{ accountName, accountNumber, ifsc, bankName, branch, accountType }` | All strings |
| `contactPhone`, `contactWhatsapp`, `contactEmail` | string | "Contact Now" options |
| `purposes` | array of LocalizedText | Dropdown options in the "Share donation details" form |
| `notifyEmail` | string, comma-separated string, or array | Office address(es) e-mailed for every new donation form (needs the *Trigger Email* extension). Publicly readable — use an official address. |

### `kirtan_categories/{categoryId}`
`name: LocalizedText`, `order`, `isActive`, `imageUrl?: MediaRef`

### `kirtans/{kirtanId}`
| Field | Type | Notes |
|---|---|---|
| `title` | LocalizedText | required |
| `poet` | LocalizedText | Rachayita, e.g. Premanand Swami |
| `singer` | LocalizedText | |
| `categoryId` | string | → `kirtan_categories` |
| `audioUrl` | MediaRef | MP3/M4A. 96–128 kbps recommended for instant start |
| `durationSec` | number | optional (shown before playing) |
| `sizeBytes` | number | optional (shown on download) |
| `lyrics` | LocalizedText | optional |
| `coverUrl` | MediaRef | optional artwork (lock screen) |
| `order`, `isActive`, `isFeatured` | | `isFeatured` → Home "Featured Kirtans" |
| `createdAt` | timestamp | |

*Auto-created:* uploading an audio file to Storage at `kirtans/{categoryId}/{file}.mp3`
creates/updates the document (title from file name, size, URL). Edit titles/poet afterwards.

### `places/{placeId}` — Prasadi places
| Field | Type | Notes |
|---|---|---|
| `name`, `shortDescription`, `mahima`, `address` | LocalizedText | `mahima` = the greatness/story (long text) |
| `location` | geopoint | Map pin |
| `category` | string | `temple` · `yagna` · `water` · `tree` · `residence` · `other` |
| `images` | array of MediaRef | First image = cover |
| `panoramaUrls` | array of MediaRef | 360° equirectangular photos (2:1) for in-app 360° darshan |
| `streetView` | map `{ lat, lng, heading, pitch }` | optional; Google Street View viewpoint (defaults to `location`) |
| `order`, `isActive` | | |

### `albums/{albumId}` and `albums/{albumId}/photos/{photoId}` — Gallery
Album: `title`, `description: LocalizedText`, `coverUrl: MediaRef`, `eventDate: timestamp`,
`order`, `isActive`, `isFeatured`, `photoCount: number` (maintained by Cloud Functions).

Photo: `url: MediaRef` (full size), `thumbUrl?: MediaRef`, `caption?: LocalizedText`,
`order?`, `width?`, `height?`, `createdAt`.

*Auto-created:* uploading images to Storage at `gallery/{albumId}/{file}.jpg`
creates the photo documents, keeps `photoCount` in sync and sets the album cover
if empty. The "Avsar 200" album id is `avsar-200`.

### `book_categories/{categoryId}`
`name: LocalizedText`, `order`, `isActive`

### `books/{bookId}` — Shastra library
| Field | Type | Notes |
|---|---|---|
| `title`, `author`, `description` | LocalizedText | |
| `categoryId` | string | → `book_categories` |
| `language` | string | `gu` · `hi` · `en` · `sa` (language of the PDF) |
| `pdfUrl` | MediaRef | required |
| `coverUrl` | MediaRef | optional |
| `pageCount`, `sizeBytes` | number | optional |
| `order`, `isActive`, `isFeatured`, `createdAt` | | |

*Auto-created:* uploading a PDF to Storage at `books/{categoryId}/{file}.pdf` creates the document.

### `events/{eventId}` — Utsav, katha & announcements
| Field | Type | Notes |
|---|---|---|
| `title`, `shortDescription`, `description`, `location` | LocalizedText | |
| `bannerUrl` | MediaRef | 16:9 banner |
| `startAt` | timestamp | required — decides Upcoming vs Past |
| `endAt` | timestamp | optional (multi-day utsav) |
| `type` | string | `utsav` · `katha` · `announcement` · `other` |
| `albumId` | string | optional → "View Photos" |
| `liveUrl` | string | optional YouTube/live link → "Watch Live" |
| `isActive` | bool | |
| `sendNotification` | bool | When `true`, a push notification is sent **once** to all devotees (in their language) |
| `notifiedAt` | timestamp | written by Cloud Functions when the send is claimed — do not edit |
| `notificationStatus`, `notificationError` | string | written by Cloud Functions (`sending` → `sent` / `error`) — do not edit |

Upcoming = `endAt ?? startAt` is today or later (ascending). Past = the rest (newest first).

### `notifications/{id}` — ad-hoc push messages (optional)
Create a document to broadcast any message: `title`, `body: LocalizedText`,
`imageUrl?: MediaRef`, `route?: string` (e.g. `/events/abc`, `/kirtan`, `/home/donate`),
`eventId?: string` (`holi-2027`, `events/holi-2027` and `/events/holi-2027` all work; an
id that matches no event is dropped and the tap opens `/events`). Empty title/body/image
are filled from the event. Cloud Functions send it and write `status`, `sentAt`, `error`,
`successCount`, `failureCount` and the `route` actually used.

### `donation_requests/{id}` — written by the app (create-only)
`name`, `phone`, `email?`, `amount?: number`, `purpose?`, `method` (`upi` · `bank` · `cash` · `cheque` · `other`),
`transactionRef?`, `message?`, `language`, `platform`, `appVersion`, `status: "new"`, `createdAt: serverTimestamp`.
Devotees cannot read these; temple staff see them in the console (and get an alert, see Functions).

### Fields written by Cloud Functions (do not edit)

* Auto-created kirtans, books and photos also carry `storagePath`, `contentType` and `updatedAt`;
  photos made by the *Resize Images* extension link `thumbUrl` / `thumbStoragePath`.
* A gallery file is treated as a thumbnail only inside a `thumbs/` folder or when the
  extension marked it `resizedImage=true`.
* Photo `order` comes from the file name: a leading number (`01 - Arti.jpg`), a
  number-only name (`001.jpg`), Windows bulk-rename (`Avsar (12).jpg`) or a camera
  sequence (`IMG_0042.jpg`, `DSC01234.jpg`).
* `mail/{id}` — documents in the format of the official *Trigger Email from Firestore*
  extension, written for new donation forms when `config/donation.notifyEmail` is set.
  No client access.

## Push notifications (FCM)

* Each device subscribes to exactly one topic matching its app language:
  `lang_en`, `lang_gu` or `lang_hi` (unsubscribed when notifications are turned off).
* Messages carry `notification { title, body, image? }` and
  `data { type: "event" | "general", eventId?, route? }`.
* Tapping opens `route`, or `/events/{eventId}` when `eventId` is set, otherwise `/events`.
* Android channel id: `utsav_updates`.
* Campaigns sent from the Firebase console "Messaging" composer also work — add
  custom data `route` = `/events` (or any route above) to control where a tap lands.

## Storage layout

```
kirtans/{categoryId}/*.mp3|m4a   → auto-creates kirtans docs
gallery/{albumId}/*.jpg|png|webp → auto-creates album photos
books/{categoryId}/*.pdf         → auto-creates books docs
places/{placeId}/*               → place photos & 360° panoramas (reference in the doc)
events/*                         → event banners
config/*                         → donation QR, hero image, etc.
```
All of Storage is publicly readable by the app and writable only by admins (console).

## Cost notes

The app keeps live listeners on small collections and the offline cache serves repeat
visits. Firestore bills a full re-read when a listener reconnects after ~30 minutes, so
the largest recurring cost is the featured album's photo list on the Home screen
(one read per photo). For albums with many hundreds of photos, prefer featuring a
smaller highlights album via `config/app.featuredAlbumId`.
