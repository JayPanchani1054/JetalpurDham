#!/usr/bin/env node
/**
 * Loads the starter content (seed-data.json) into Cloud Firestore.
 *
 *   cd tools/seed
 *   npm install
 *   gcloud auth application-default login      # or GOOGLE_APPLICATION_CREDENTIALS=key.json
 *   node seed.mjs --project <firebase-project-id> [--dry-run]
 *
 * Safe to run any number of times: it creates missing documents and adds
 * missing fields, but NEVER overwrites a value that already exists, so edits
 * made by temple staff in the Firebase console are always kept. To re-apply a
 * seeded value, delete that field (or document) in the console and run again.
 *
 * Works against the Firestore emulator too: set FIRESTORE_EMULATOR_HOST.
 */
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, GeoPoint, getFirestore, Timestamp } from 'firebase-admin/firestore';

const here = dirname(fileURLToPath(import.meta.url));

const USAGE = `Usage: node seed.mjs --project <firebase-project-id> [options]

Options:
  --project, -p <id>   Firebase project id (or set GOOGLE_CLOUD_PROJECT)
  --dry-run            Show what would be written without writing anything
  --data <file>        Seed file (default: seed-data.json next to this script)
  --help, -h           Show this help`;

function fail(message) {
  console.error(`\n✖ ${message}\n`);
  process.exit(1);
}

let args;
try {
  args = parseArgs({
    options: {
      project: { type: 'string', short: 'p' },
      'dry-run': { type: 'boolean', default: false },
      data: { type: 'string', default: resolve(here, 'seed-data.json') },
      help: { type: 'boolean', short: 'h', default: false },
    },
    strict: true,
  }).values;
} catch (error) {
  fail(`${error.message}\n\n${USAGE}`);
}
if (args.help) {
  console.log(USAGE);
  process.exit(0);
}

const projectId = args.project ?? process.env.GOOGLE_CLOUD_PROJECT ?? process.env.GCLOUD_PROJECT;
if (!projectId) fail(`Missing --project.\n\n${USAGE}`);
const dryRun = args['dry-run'];
const emulator = process.env.FIRESTORE_EMULATOR_HOST;

/** Converts the JSON encodings for Firestore types into real values. */
function decode(value, path) {
  if (Array.isArray(value)) return value.map((v, i) => decode(v, `${path}[${i}]`));
  if (value === null || typeof value !== 'object') return value;
  if ('$geopoint' in value) {
    const [lat, lng] = value.$geopoint;
    if (typeof lat !== 'number' || typeof lng !== 'number') throw new Error(`Bad $geopoint at ${path}`);
    return new GeoPoint(lat, lng);
  }
  if ('$timestamp' in value) {
    const date = new Date(value.$timestamp);
    if (Number.isNaN(date.getTime())) throw new Error(`Bad $timestamp at ${path}`);
    return Timestamp.fromDate(date);
  }
  return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, decode(v, `${path}.${k}`)]));
}

async function main() {
  let seed;
  try {
    seed = JSON.parse(await readFile(args.data, 'utf8'));
  } catch (error) {
    fail(`Could not read ${args.data}: ${error.message}`);
  }
  const collections = seed?.collections;
  if (!collections || typeof collections !== 'object') fail(`${args.data} has no "collections" object.`);

  initializeApp(emulator ? { projectId } : { credential: applicationDefault(), projectId });
  const db = getFirestore();

  console.log(`Seeding project "${projectId}"${emulator ? ` (emulator ${emulator})` : ''}${dryRun ? ' — DRY RUN, nothing is written' : ''}\n`);

  const totals = { created: 0, updated: 0, unchanged: 0 };
  for (const [collection, docs] of Object.entries(collections)) {
    for (const [docId, raw] of Object.entries(docs)) {
      const path = `${collection}/${docId}`;
      const data = decode(raw, path);
      const ref = db.collection(collection).doc(docId);
      const snap = await ref.get();

      if (!snap.exists) {
        // config/* are settings documents; everything else gets a createdAt.
        const doc = collection === 'config' ? data : { ...data, createdAt: FieldValue.serverTimestamp() };
        if (!dryRun) await ref.set(doc);
        totals.created++;
        console.log(`  + ${path}  (created)`);
        continue;
      }

      const existing = snap.data() ?? {};
      const missing = Object.fromEntries(Object.entries(data).filter(([key]) => !(key in existing)));
      const keys = Object.keys(missing);
      if (keys.length === 0) {
        totals.unchanged++;
        console.log(`  = ${path}  (unchanged)`);
        continue;
      }
      if (!dryRun) await ref.set(missing, { merge: true });
      totals.updated++;
      console.log(`  ~ ${path}  (added ${keys.join(', ')})`);
    }
  }

  console.log(`\nDone: ${totals.created} created, ${totals.updated} updated, ${totals.unchanged} unchanged.`);
  if (dryRun) console.log('Dry run: run again without --dry-run to write these changes.');
}

main().catch((error) => {
  const hint =
    /credential|authenticat|default credentials|PERMISSION_DENIED|UNAUTHENTICATED/i.test(String(error?.message))
      ? '\nSign in first: `gcloud auth application-default login`, or set GOOGLE_APPLICATION_CREDENTIALS to a service-account key file (see docs/FIREBASE_SETUP.md).'
      : '';
  fail(`${error?.message ?? error}${hint}`);
});
