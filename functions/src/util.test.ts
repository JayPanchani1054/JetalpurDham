import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { DonationEmailLimits, DonationRetention } from './config';
import {
  asBool,
  buildDonationEmail,
  buildDonationPausedEmail,
  buildMessages,
  classifyObject,
  compactPhone,
  DEFAULT_BODY,
  DEFAULT_TITLE,
  donationConsoleUrl,
  donationEmailSkipReason,
  donationMailId,
  donationPausedMailId,
  escapeHtml,
  eventRoute,
  extensionOf,
  formatRupees,
  hasText,
  httpsUrlOrNull,
  humanize,
  indiaDateKey,
  isNotificationPending,
  isStaleEvent,
  leadingOrder,
  localize,
  localizedTitle,
  newAlbumFields,
  newBookFields,
  newKirtanFields,
  normalizeEventId,
  notificationRoute,
  parseEmails,
  parseGsUrl,
  photoOrder,
  prettyTitle,
  pushText,
  retentionCutoff,
  retentionMonths,
  safeRoute,
  samePhoneCount,
  scriptLanguage,
  shouldNotifyEvent,
  slug,
  stableId,
  stripExtension,
  truncate,
} from './util';

describe('localize', () => {
  it('uses a plain string for every language', () => {
    assert.equal(localize('  Avsar 200 ', 'gu'), 'Avsar 200');
  });

  it('picks the requested language from a map', () => {
    const text = { en: 'Kirtan', gu: 'કીર્તન', hi: 'कीर्तन' };
    assert.equal(localize(text, 'en'), 'Kirtan');
    assert.equal(localize(text, 'gu'), 'કીર્તન');
    assert.equal(localize(text, 'hi'), 'कीर्तन');
  });

  it('falls back English → Gujarati → Hindi → any key', () => {
    assert.equal(localize({ gu: 'ઉત્સવ', en: 'Utsav' }, 'hi'), 'Utsav');
    assert.equal(localize({ hi: 'उत्सव', gu: 'ઉત્સવ' }, 'en'), 'ઉત્સવ');
    assert.equal(localize({ hi: 'उत्सव' }, 'gu'), 'उत्सव');
    assert.equal(localize({ sa: 'उत्सवः' }, 'en'), 'उत्सवः');
  });

  it('ignores blank and wrongly-typed values and accepts upper-case keys', () => {
    assert.equal(localize({ EN: 'Hello', gu: '  ' }, 'gu'), 'Hello');
    assert.equal(localize({ en: 42, gu: 'નમસ્તે' }, 'en'), 'નમસ્તે');
    assert.equal(localize(null, 'en'), '');
    assert.equal(localize(12, 'en'), '');
    assert.equal(localize(['a'], 'en'), '');
    assert.equal(hasText({ en: ' ' }), false);
    assert.equal(hasText({ hi: 'धुन' }), true);
  });
});

describe('text helpers', () => {
  it('truncates at a word boundary with an ellipsis', () => {
    assert.equal(truncate('short text', 20), 'short text');
    const cut = truncate('The quick brown fox jumps over the lazy dog', 20);
    assert.equal(cut, 'The quick brown fox…');
    assert.ok(Array.from(cut).length <= 20);
  });

  it('truncates Gujarati safely', () => {
    const text = 'જેતલપુરધામ '.repeat(30);
    const cut = truncate(text, 50);
    assert.ok(Array.from(cut).length <= 50);
    assert.ok(cut.endsWith('…'));
  });

  it('reads booleans like the app', () => {
    assert.equal(asBool(true, false), true);
    assert.equal(asBool('TRUE', false), true);
    assert.equal(asBool('no', true), false);
    assert.equal(asBool(0, true), false);
    assert.equal(asBool(undefined, true), true);
    assert.equal(asBool('maybe', false), false);
  });

  it('validates https URLs and gs:// URLs', () => {
    assert.equal(httpsUrlOrNull('https://example.com/a.jpg'), 'https://example.com/a.jpg');
    assert.equal(httpsUrlOrNull('http://example.com/a.jpg'), null);
    assert.equal(httpsUrlOrNull('https://'), null);
    assert.equal(httpsUrlOrNull(5), null);
    assert.deepEqual(parseGsUrl('gs://my-bucket/events/banner 1.jpg'), {
      bucket: 'my-bucket',
      path: 'events/banner 1.jpg',
    });
    assert.equal(parseGsUrl('gs://only-bucket'), null);
  });

  it('detects stale retried events', () => {
    const now = Date.parse('2026-10-11T10:00:00Z');
    assert.equal(isStaleEvent('2026-10-11T09:30:00Z', now, 3_600_000), false);
    assert.equal(isStaleEvent('2026-10-11T08:00:00Z', now, 3_600_000), true);
    assert.equal(isStaleEvent(undefined, now, 1), false);
    assert.equal(isStaleEvent('not a date', now, 1), false);
  });
});

describe('routes', () => {
  it('builds event routes like the app', () => {
    assert.equal(eventRoute('avsar-200'), '/events/avsar-200');
    assert.equal(eventRoute('a b/c'), '/events/a%20b%2Fc');
  });

  it('allows only internal app locations', () => {
    for (const ok of ['/events', '/events/abc', '/kirtan', '/home/donate', '/home/gallery/avsar-200', '/places/dev-sarovar', '/library', '/reader/vachanamrut']) {
      assert.equal(safeRoute(ok), ok, ok);
    }
    for (const bad of ['', 'events', '//evil.com', 'https://evil.com', '/admin', '/events/a b', 42, null]) {
      assert.equal(safeRoute(bad), null, String(bad));
    }
    assert.equal(safeRoute('  /kirtan  '), '/kirtan');
  });

  it('accepts event ids the way staff paste them', () => {
    assert.equal(normalizeEventId('holi-2027'), 'holi-2027');
    assert.equal(normalizeEventId('  events/holi-2027 '), 'holi-2027');
    assert.equal(normalizeEventId('/events/holi-2027/'), 'holi-2027');
    assert.equal(normalizeEventId('/events/a%20b'), 'a b');
    assert.equal(normalizeEventId('events/a/b'), null);
    assert.equal(normalizeEventId('__x__'), null);
    assert.equal(normalizeEventId(''), null);
    assert.equal(normalizeEventId(undefined), null);
    assert.equal(normalizeEventId(2027), '2027');
  });

  it('chooses the tap destination of an ad-hoc notification', () => {
    assert.equal(notificationRoute('/home/donate', 'x'), '/home/donate');
    assert.equal(notificationRoute('https://bad', 'holi'), '/events/holi');
    assert.equal(notificationRoute(undefined, null), '/events');
  });
});

describe('push messages', () => {
  const event = {
    title: { en: 'Holi Utsav', gu: 'હોળી ઉત્સવ' },
    shortDescription: { en: 'Join us on Phagan sud 15', hi: 'फाल्गुन पूर्णिमा पर पधारें' },
    description: 'Long description',
  };

  it('localizes title and body with fallbacks', () => {
    const push = { title: event.title, body: event.shortDescription, fallbackBody: event.description, data: {} };
    assert.deepEqual(pushText(push, 'gu'), { title: 'હોળી ઉત્સવ', body: 'Join us on Phagan sud 15' });
    assert.deepEqual(pushText(push, 'hi'), { title: 'Holi Utsav', body: 'फाल्गुन पूर्णिमा पर पधारें' });
  });

  it('uses the first 140 characters of the description when there is no short text', () => {
    const description = `${'word '.repeat(60)}end`;
    const { body } = pushText({ title: 'T', fallbackBody: description, data: {} }, 'en');
    assert.ok(Array.from(body).length <= 140);
    assert.ok(body.endsWith('…'));
  });

  it('falls back to default title and body', () => {
    assert.deepEqual(pushText({ title: null, data: {} }, 'gu'), { title: DEFAULT_TITLE.gu, body: DEFAULT_BODY.gu });
    assert.deepEqual(pushText({ title: '', body: { en: ' ' }, data: {} }, 'hi'), {
      title: DEFAULT_TITLE.hi,
      body: DEFAULT_BODY.hi,
    });
  });

  it('builds one message per language topic with the app contract', () => {
    const messages = buildMessages({
      title: event.title,
      body: event.shortDescription,
      imageUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/events%2Fholi.jpg?alt=media&token=t',
      data: { type: 'event', eventId: 'holi', route: '/events/holi' },
    });
    assert.deepEqual(
      messages.map((m) => m.topic),
      ['lang_en', 'lang_gu', 'lang_hi'],
    );
    const [en, gu] = messages;
    assert.ok(en && gu);
    assert.equal(en.notification?.title, 'Holi Utsav');
    assert.equal(gu.notification?.title, 'હોળી ઉત્સવ');
    assert.deepEqual(en.data, { type: 'event', eventId: 'holi', route: '/events/holi' });
    assert.ok(en.notification?.imageUrl?.startsWith('https://'));
    assert.equal(en.android?.priority, 'high');
    assert.deepEqual(en.android?.notification, {
      channelId: 'utsav_updates',
      color: '#C2410C',
      icon: 'ic_notification',
      imageUrl: en.notification?.imageUrl,
    });
    assert.deepEqual(en.apns?.payload?.aps, { sound: 'default', mutableContent: true });
    assert.equal(en.apns?.fcmOptions?.imageUrl, en.notification?.imageUrl);
    // Each message owns its objects (the Admin SDK mutates them while validating).
    assert.notEqual(en.data, gu.data);
    assert.notEqual(en.apns?.payload, gu.apns?.payload);
  });

  it('omits images that are not https', () => {
    for (const imageUrl of [null, undefined, 'http://x.com/a.jpg', 'events/banner.jpg']) {
      const [message] = buildMessages({ title: 'T', imageUrl, data: { route: '/events' } }, ['en']);
      assert.ok(message);
      assert.equal(message.notification?.imageUrl, undefined);
      assert.equal(message.android?.notification?.imageUrl, undefined);
      assert.equal(message.apns?.fcmOptions, undefined);
    }
  });

  it('drops non-string data values', () => {
    const [message] = buildMessages({ title: 'T', data: { route: '/events', bad: 1 as unknown as string } }, ['hi']);
    assert.deepEqual(message?.data, { route: '/events' });
  });
});

describe('shouldNotifyEvent', () => {
  const base = { title: { en: 'Annakut' }, sendNotification: true };

  it('sends active, titled, not-yet-notified events', () => {
    assert.equal(shouldNotifyEvent(base), true);
    assert.equal(shouldNotifyEvent({ ...base, isActive: true, notifiedAt: null }), true);
    assert.equal(shouldNotifyEvent({ ...base, sendNotification: 'true', notifiedAt: '' }), true);
  });

  it('skips everything else', () => {
    assert.equal(shouldNotifyEvent(undefined), false);
    assert.equal(shouldNotifyEvent({ ...base, sendNotification: false }), false);
    assert.equal(shouldNotifyEvent({ title: 'x' }), false);
    assert.equal(shouldNotifyEvent({ ...base, isActive: false }), false);
    assert.equal(shouldNotifyEvent({ ...base, isActive: 'false' }), false);
    assert.equal(shouldNotifyEvent({ ...base, notifiedAt: new Date() }), false);
    assert.equal(shouldNotifyEvent({ ...base, title: { en: '  ' } }), false);
  });

  it('treats only unsent ad-hoc notifications as pending', () => {
    assert.equal(isNotificationPending({ title: 'x' }), true);
    assert.equal(isNotificationPending({ title: 'x', status: 'new' }), true);
    assert.equal(isNotificationPending({ status: 'SENT' }), false);
    assert.equal(isNotificationPending({ status: 'sending' }), false);
    assert.equal(isNotificationPending({ status: 'error' }), false);
    assert.equal(isNotificationPending(null), false);
  });
});

describe('file names', () => {
  it('slugs and builds stable ids', () => {
    assert.equal(slug('Jay Sadguru Swámi!'), 'jay-sadguru-swami');
    assert.equal(stableId('aarti-stuti/01 - Jay Sadguru Swami'), 'aarti-stuti-01-jay-sadguru-swami');
    const gu = stableId('thal/જમો થાળ જીવન');
    assert.match(gu, /^thal-[0-9a-f]{10}$/u);
    assert.equal(gu, stableId('thal/જમો થાળ જીવન'));
    assert.notEqual(gu, stableId('thal/જમો થાળ'));
    assert.match(stableId('૧૨૩'), /^[0-9a-f]{10}$/u);
    const long = stableId(`dhun/${'a'.repeat(200)}`);
    assert.ok(long.length <= 96);
    assert.notEqual(long, stableId(`dhun/${'a'.repeat(201)}`));
  });

  it('splits extensions', () => {
    assert.equal(stripExtension('01 - Jay.mp3'), '01 - Jay');
    assert.equal(stripExtension('.hidden'), '.hidden');
    assert.equal(extensionOf('Book.PDF'), 'pdf');
    assert.equal(extensionOf('noext'), '');
  });

  it('reads leading track numbers', () => {
    assert.equal(leadingOrder('01 - Jay.mp3'), 1);
    assert.equal(leadingOrder('12_Thal.mp3'), 12);
    assert.equal(leadingOrder('003 Dhun.mp3'), 3);
    assert.equal(leadingOrder('1. Aarti.m4a'), 1);
    assert.equal(leadingOrder('7) Stuti.mp3'), 7);
    assert.equal(leadingOrder('Jay.mp3'), null);
    assert.equal(leadingOrder('2026 Holi.jpg'), null);
    assert.equal(leadingOrder('01.mp3'), null);
  });

  it('orders photos by the number in their file name', () => {
    assert.equal(photoOrder('01 - Aarti.jpg'), 1);
    assert.equal(photoOrder('001.jpg'), 1);
    assert.equal(photoOrder('0153.JPG'), 153);
    assert.equal(photoOrder('Avsar (12).jpg'), 12);
    assert.equal(photoOrder('Avsar(3).jpeg'), 3);
    assert.equal(photoOrder('IMG_0042.jpg'), 42);
    assert.equal(photoOrder('DSC01234.JPG'), 1234);
    assert.equal(photoOrder('IMG-20260305-WA0001.jpg'), null);
    assert.equal(photoOrder('20260305_101010.jpg'), null);
    assert.equal(photoOrder('Mandir at night.jpg'), null);
    assert.equal(photoOrder('1234567.jpg'), null);
  });

  it('makes readable titles', () => {
    assert.equal(prettyTitle('01 - jay_sadguru_swami.mp3'), 'Jay Sadguru Swami');
    assert.equal(prettyTitle('JAY-SADGURU-SWAMI.mp3'), 'Jay Sadguru Swami');
    assert.equal(prettyTitle('05_Ora Avo Shyam Sanehi.m4a'), 'Ora Avo Shyam Sanehi');
    assert.equal(prettyTitle('Vachanamrut.pdf'), 'Vachanamrut');
    assert.equal(prettyTitle('03 - જમો થાળ જીવન.mp3'), 'જમો થાળ જીવન');
    assert.equal(prettyTitle('Jay%20Swaminarayan.mp3'), 'Jay Swaminarayan');
    assert.equal(prettyTitle('01.mp3'), '01');
    assert.equal(prettyTitle('Shree HariLila.mp3'), 'Shree HariLila');
    assert.equal(humanize('avsar-200'), 'Avsar 200');
    assert.equal(humanize('holi_2026'), 'Holi 2026');
  });

  it('keys auto titles by script', () => {
    assert.equal(scriptLanguage('Jay'), 'en');
    assert.equal(scriptLanguage('જય'), 'gu');
    assert.equal(scriptLanguage('जय'), 'hi');
    assert.deepEqual(localizedTitle('થાળ'), { gu: 'થાળ' });
    assert.deepEqual(localizedTitle('Thal'), { en: 'Thal' });
  });
});

describe('classifyObject', () => {
  it('maps kirtan uploads', () => {
    assert.deepEqual(classifyObject('kirtans/aarti-stuti/01 - Jay Sadguru Swami.mp3', 'audio/mpeg'), {
      kind: 'kirtan',
      categoryId: 'aarti-stuti',
      fileName: '01 - Jay Sadguru Swami.mp3',
      docId: 'aarti-stuti-01-jay-sadguru-swami',
    });
    assert.equal(classifyObject('kirtans/dhun/dhun.m4a', 'application/octet-stream').kind, 'kirtan');
    assert.equal(classifyObject('kirtans/dhun/cover.jpg', 'image/jpeg').kind, 'ignore');
    assert.equal(classifyObject('kirtans/song.mp3', 'audio/mpeg').kind, 'ignore');
  });

  it('keeps the same id when a kirtan is re-uploaded in another format', () => {
    const mp3 = classifyObject('kirtans/thal/Jamo Thal.mp3', 'audio/mpeg');
    const m4a = classifyObject('kirtans/thal/Jamo Thal.m4a', 'audio/mp4');
    assert.ok(mp3.kind === 'kirtan' && m4a.kind === 'kirtan');
    assert.equal(mp3.docId, m4a.docId);
  });

  it('maps gallery photos and their thumbnails to the same photo id', () => {
    const photo = classifyObject('gallery/avsar-200/IMG_0001.jpg', 'image/jpeg');
    assert.deepEqual(photo, { kind: 'photo', albumId: 'avsar-200', fileName: 'IMG_0001.jpg', docId: 'img-0001' });
    const thumb = classifyObject('gallery/avsar-200/thumbs/IMG_0001_400x400.webp', 'image/webp');
    assert.deepEqual(thumb, {
      kind: 'thumb',
      albumId: 'avsar-200',
      fileName: 'IMG_0001_400x400.webp',
      photoId: 'img-0001',
    });
    // Resize Images output next to the original is recognised by its metadata.
    const sideBySide = classifyObject('gallery/avsar-200/IMG_0001_200x200.jpg', 'image/jpeg', { resizedImage: 'true' });
    assert.equal(sideBySide.kind === 'thumb' && sideBySide.photoId, 'img-0001');
    assert.equal(classifyObject('gallery/avsar-200/thumbs/readme.jpg', 'image/jpeg').kind, 'ignore');
  });

  it('keeps a devotee photo whose name merely looks like a thumbnail', () => {
    assert.deepEqual(classifyObject('gallery/avsar-200/Stage_1920x1080.jpg', 'image/jpeg'), {
      kind: 'photo',
      albumId: 'avsar-200',
      fileName: 'Stage_1920x1080.jpg',
      docId: 'stage-1920x1080',
    });
    assert.equal(classifyObject('gallery/avsar-200/Stage_1920x1080.jpg', 'image/jpeg', { resizedImage: 'false' }).kind, 'photo');
    assert.equal(classifyObject('gallery/avsar-200/Stage_1920x1080.jpg', 'image/jpeg', null).kind, 'photo');
  });

  it('rejects unsupported gallery files', () => {
    assert.equal(classifyObject('gallery/avsar-200/IMG_1.HEIC', 'image/heic').kind, 'ignore');
    assert.equal(classifyObject('gallery/avsar-200/logo.svg', 'image/svg+xml').kind, 'ignore');
    assert.equal(classifyObject('gallery/avsar-200/video.mp4', 'video/mp4').kind, 'ignore');
    assert.equal(classifyObject('gallery/avsar-200/.DS_Store', null).kind, 'ignore');
    assert.equal(classifyObject('gallery/__bad__/a.jpg', 'image/jpeg').kind, 'ignore');
  });

  it('maps books and ignores other folders', () => {
    assert.deepEqual(classifyObject('books/core/Vachanamrut.pdf', 'application/pdf'), {
      kind: 'book',
      categoryId: 'core',
      fileName: 'Vachanamrut.pdf',
      docId: 'core-vachanamrut',
    });
    assert.equal(classifyObject('books/core/notes.txt', 'text/plain').kind, 'ignore');
    assert.equal(classifyObject('places/dev-sarovar/360.jpg', 'image/jpeg').kind, 'ignore');
    assert.equal(classifyObject('events/holi.jpg', 'image/jpeg').kind, 'ignore');
    assert.equal(classifyObject('gallery/avsar-200/', null).kind, 'ignore');
    assert.equal(classifyObject(undefined).kind, 'ignore');
  });

  it('uses sub-folders in the id so equal file names do not collide', () => {
    const a = classifyObject('gallery/avsar-200/day-1/01.jpg', 'image/jpeg');
    const b = classifyObject('gallery/avsar-200/day-2/01.jpg', 'image/jpeg');
    assert.ok(a.kind === 'photo' && b.kind === 'photo');
    assert.notEqual(a.docId, b.docId);
  });
});

describe('new document fields', () => {
  it('creates kirtans with a title, order and category', () => {
    assert.deepEqual(newKirtanFields('thal', '02 - Jamo Thal Jivan.mp3'), {
      title: { en: 'Jamo Thal Jivan' },
      categoryId: 'thal',
      order: 2,
      isActive: true,
    });
    assert.equal('order' in newKirtanFields('thal', 'Jamo Thal.mp3'), false);
  });

  it('creates books in Gujarati by default', () => {
    assert.deepEqual(newBookFields('core', 'શિક્ષાપત્રી.pdf'), {
      title: { gu: 'શિક્ષાપત્રી' },
      categoryId: 'core',
      language: 'gu',
      isActive: true,
    });
  });

  it('creates albums titled from their folder', () => {
    assert.deepEqual(newAlbumFields('janmashtami-2026'), { title: { en: 'Janmashtami 2026' }, isActive: true });
  });
});

describe('donation e-mail', () => {
  it('parses one or many addresses', () => {
    assert.deepEqual(parseEmails('office@temple.org'), ['office@temple.org']);
    assert.deepEqual(parseEmails('a@x.in, B@x.in; a@x.in'), ['a@x.in', 'b@x.in']);
    assert.deepEqual(parseEmails(['a@x.in', 'not-an-email', 7]), ['a@x.in']);
    assert.deepEqual(parseEmails(''), []);
    assert.deepEqual(parseEmails(undefined), []);
  });

  it('escapes HTML and formats rupees', () => {
    assert.equal(escapeHtml(`<b onclick="x">'&'</b>`), '&lt;b onclick=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/b&gt;');
    assert.equal(formatRupees(125000), '₹1,25,000');
    assert.equal(formatRupees(501.5), '₹501.5');
  });

  it('summarises a request safely', () => {
    const email = buildDonationEmail(
      {
        name: 'Ramesh <script>alert(1)</script> Patel',
        phone: '+91 98765 43210',
        email: 'ramesh@example.com',
        amount: 5100,
        purpose: 'Thal / Annakut',
        method: 'upi',
        transactionRef: '412345678901',
        message: 'Jay Swaminarayan\nPlease send receipt',
        language: 'gu',
        platform: 'android',
        appVersion: '1.0.0+1',
        status: 'new',
      },
      'req123',
      { projectId: 'jetalpur-dham', submittedAt: new Date('2026-03-05T04:30:00Z') },
    );
    assert.match(email.subject, /^New donation details: Ramesh <script>alert\(1\)<\/script> Patel \(₹5,100\)$/u);
    assert.ok(!email.html.includes('<script>'));
    assert.ok(email.html.includes('&lt;script&gt;'));
    assert.ok(email.text.includes('Phone: +91 98765 43210'));
    assert.ok(email.text.includes('Paid by: UPI'));
    assert.ok(email.text.includes('App language: Gujarati'));
    assert.ok(email.text.includes('Device: android · 1.0.0+1'));
    assert.ok(email.text.includes('Submitted: 5 Mar 2026'));
    assert.ok(email.text.includes('/project/jetalpur-dham/firestore/databases/-default-/data/~2Fdonation_requests~2Freq123'));
    assert.equal(email.replyTo, 'ramesh@example.com');
  });

  it('copes with a nearly empty request', () => {
    const email = buildDonationEmail({ phone: 12345678, amount: 'abc', email: 'nope' }, 'r1');
    assert.equal(email.subject, 'New donation details: A devotee');
    assert.ok(email.text.includes('Phone: 12345678'));
    assert.ok(!email.text.includes('Amount'));
    assert.ok(!email.text.includes('Open in Firebase console'));
    assert.equal(email.replyTo, null);
    assert.equal(buildDonationEmail(null, 'r2').subject, 'New donation details: A devotee');
  });
});

describe('donation e-mail limits', () => {
  const limits = { perHour: 3, perDay: 10, perPhonePerDay: 2 };

  it('sends while every count is within its limit (counts include the new form)', () => {
    assert.equal(donationEmailSkipReason({ lastHour: 1, lastDay: 1, samePhoneLastDay: 1 }, limits), null);
    assert.equal(donationEmailSkipReason({ lastHour: 3, lastDay: 10, samePhoneLastDay: 2 }, limits), null);
    assert.equal(donationEmailSkipReason({ lastHour: 3, lastDay: 10 }, limits), null);
    assert.equal(donationEmailSkipReason({ lastHour: 3, lastDay: 10, samePhoneLastDay: null }, limits), null);
  });

  it('skips from the form after the limit on, global limits first', () => {
    assert.equal(donationEmailSkipReason({ lastHour: 4, lastDay: 4, samePhoneLastDay: 1 }, limits), 'hourly-limit');
    assert.equal(donationEmailSkipReason({ lastHour: 4, lastDay: 11, samePhoneLastDay: 9 }, limits), 'hourly-limit');
    assert.equal(donationEmailSkipReason({ lastHour: 2, lastDay: 11, samePhoneLastDay: 9 }, limits), 'daily-limit');
    assert.equal(donationEmailSkipReason({ lastHour: 2, lastDay: 5, samePhoneLastDay: 3 }, limits), 'phone-limit');
  });

  it('has sane defaults that keep a day under Gmail\'s 500 e-mails', () => {
    assert.ok(DonationEmailLimits.perPhonePerDay >= 1);
    assert.ok(DonationEmailLimits.perHour <= DonationEmailLimits.perDay);
    assert.ok(DonationEmailLimits.perDay < 500);
    assert.equal(donationEmailSkipReason({ lastHour: 1, lastDay: 1, samePhoneLastDay: 1 }), null);
    assert.equal(
      donationEmailSkipReason({ lastHour: DonationEmailLimits.perHour + 1, lastDay: DonationEmailLimits.perHour + 1 }),
      'hourly-limit',
    );
  });

  it('compares phone numbers regardless of formatting', () => {
    assert.equal(compactPhone(' +91 98765-43210 '), '+919876543210');
    assert.equal(compactPhone('(022) 1234.5678'), '02212345678');
    assert.equal(compactPhone(''), null);
    assert.equal(compactPhone(null), null);
    const phones = ['+919876543210', '+91 98765 43210', '+919999999999', null, 42];
    assert.equal(samePhoneCount(phones, '+919876543210'), 2);
    assert.equal(samePhoneCount(phones, '+15551234567'), 0);
    assert.equal(samePhoneCount(phones, undefined), 0);
  });

  it('names mail documents deterministically', () => {
    assert.equal(donationMailId('abc123'), 'donation-abc123');
    // 19:00 UTC is already the next day in India (UTC+5:30).
    assert.equal(indiaDateKey(new Date('2026-10-11T19:00:00Z')), '2026-10-12');
    assert.equal(indiaDateKey(new Date('2026-10-11T18:00:00Z')), '2026-10-11');
    assert.equal(donationPausedMailId(new Date('2026-03-05T04:30:00Z')), 'donation-paused-2026-03-05');
  });

  it('links the console list or one request', () => {
    assert.equal(donationConsoleUrl(null), null);
    assert.equal(
      donationConsoleUrl('jd'),
      'https://console.firebase.google.com/project/jd/firestore/databases/-default-/data/~2Fdonation_requests',
    );
    assert.ok(donationConsoleUrl('jd', 'a b')?.endsWith('~2Fdonation_requests~2Fa%20b'));
  });

  it('tells staff that e-mails are paused and where to look', () => {
    const hourly = buildDonationPausedEmail('hourly-limit', { lastHour: 31, lastDay: 40 }, { projectId: 'jd', limits });
    assert.ok(hourly.text.includes('31 forms in the last hour'));
    assert.ok(hourly.text.includes('at most 3 an hour and 10 a day'));
    assert.ok(hourly.text.includes('No form is lost'));
    assert.ok(hourly.text.includes('~2Fdonation_requests'));
    assert.ok(hourly.html.includes("temple&#39;s e-mail account"));
    assert.ok(!/[\r\n]/u.test(hourly.subject));
    const daily = buildDonationPausedEmail('daily-limit', { lastHour: 2, lastDay: 151 });
    assert.ok(daily.text.includes('151 forms in the last 24 hours'));
    assert.ok(!daily.text.includes('Firebase console'));
  });
});

describe('donation retention', () => {
  it('reads the number of months safely', () => {
    assert.equal(DonationRetention.defaultMonths, 12);
    assert.equal(retentionMonths(undefined), 12);
    assert.equal(retentionMonths(''), 12);
    assert.equal(retentionMonths('18'), 18);
    assert.equal(retentionMonths(' 6 '), 6);
    assert.equal(retentionMonths(24), 24);
    assert.equal(retentionMonths('0'), 12);
    assert.equal(retentionMonths('-3'), 12);
    assert.equal(retentionMonths('1.5'), 12);
    assert.equal(retentionMonths('twelve'), 12);
    assert.equal(retentionMonths('1000'), 12);
    assert.equal(retentionMonths('1'), 1);
    assert.equal(retentionMonths('120'), 120);
  });

  it('computes the cutoff in calendar months', () => {
    const now = new Date('2026-10-12T22:00:00.000Z');
    assert.equal(retentionCutoff(now, 12).toISOString(), '2025-10-12T22:00:00.000Z');
    assert.equal(retentionCutoff(now, 1).toISOString(), '2026-09-12T22:00:00.000Z');
    assert.equal(retentionCutoff(now, 22).toISOString(), '2024-12-12T22:00:00.000Z');
  });

  it('clamps to the end of shorter months', () => {
    assert.equal(retentionCutoff(new Date('2024-02-29T03:30:00Z'), 12).toISOString(), '2023-02-28T03:30:00.000Z');
    assert.equal(retentionCutoff(new Date('2026-03-31T00:00:00Z'), 1).toISOString(), '2026-02-28T00:00:00.000Z');
    assert.equal(retentionCutoff(new Date('2028-03-31T00:00:00Z'), 1).toISOString(), '2028-02-29T00:00:00.000Z');
    assert.equal(retentionCutoff(new Date('2026-12-31T12:00:00Z'), 6).toISOString(), '2026-06-30T12:00:00.000Z');
  });

  it('never returns a cutoff at or after now', () => {
    const now = new Date('2026-10-12T22:00:00Z');
    for (let months = 1; months <= 120; months++) {
      assert.ok(retentionCutoff(now, months).getTime() < now.getTime() - 27 * 24 * 60 * 60 * 1000);
    }
    assert.throws(() => retentionCutoff(now, 0), RangeError);
    assert.throws(() => retentionCutoff(now, -1), RangeError);
    assert.throws(() => retentionCutoff(now, 1.5), RangeError);
    assert.throws(() => retentionCutoff(new Date('nope'), 12), RangeError);
  });
});
