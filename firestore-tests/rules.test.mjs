// Emulator-backed unit tests for ../firestore.rules. These exercise the
// *actual* rules engine (via the Firestore emulator), not mocked SDK calls —
// see docs/security-model.md for why that distinction matters: the app's own
// Dart-side checks (FirestoreExpenseRepository) prove nothing about what the
// backend itself will accept from a client that skips the app entirely.
//
// Run with: firebase emulators:exec --project demo-expense-tracker-rules-test
//   --only firestore "npm test"
// (from this directory, after `npm install`). See README.md in this folder
// for the full setup — these tests are not run automatically by this change.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { before, after, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  updateDoc,
  deleteDoc,
  getDoc,
  getDocs,
  collection,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const PROJECT_ID = 'demo-expense-tracker-rules-test';
const OWNER_UID = 'owner-uid';
const OTHER_UID = 'other-uid';

/** A schema-valid expense body for OWNER_UID, as the app itself would send
 * it on create (audit timestamps as serverTimestamp() sentinels). */
function validExpense(overrides = {}) {
  return {
    userId: OWNER_UID,
    title: 'Lunch',
    amount: 12.5,
    category: 'food',
    date: Timestamp.fromDate(new Date('2026-01-01T12:00:00Z')),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function ownerDb() {
  return testEnv.authenticatedContext(OWNER_UID).firestore();
}
function otherDb() {
  return testEnv.authenticatedContext(OTHER_UID).firestore();
}
function anonDb() {
  return testEnv.unauthenticatedContext().firestore();
}

/** Seeds one valid expense directly (bypassing rules) as a fixture for
 * read/update/delete tests, so those tests exercise only the rule under
 * test rather than also depending on create succeeding. */
async function seedExpense(uid, id, overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', uid, 'expenses', id), {
      userId: uid,
      title: 'Seeded',
      amount: 10,
      category: 'food',
      date: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
      createdAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
      updatedAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
      ...overrides,
    });
  });
}

describe('authentication is required', () => {
  it('an unauthenticated request cannot create an expense', async () => {
    const db = anonDb();
    await assertFails(
      setDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), validExpense()),
    );
  });

  it('an unauthenticated request cannot read an expense', async () => {
    await seedExpense(OWNER_UID, 'e1');
    const db = anonDb();
    await assertFails(getDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1')));
  });

  it('an unauthenticated request cannot list a collection', async () => {
    await seedExpense(OWNER_UID, 'e1');
    const db = anonDb();
    await assertFails(getDocs(collection(db, 'users', OWNER_UID, 'expenses')));
  });
});

describe('owner-only access at users/{uid}/expenses/*', () => {
  it('the owner can create their own expense with valid data', async () => {
    const db = ownerDb();
    await assertSucceeds(
      setDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), validExpense()),
    );
  });

  it('the owner can read their own expense', async () => {
    await seedExpense(OWNER_UID, 'e1');
    const db = ownerDb();
    await assertSucceeds(getDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1')));
  });

  it('the owner can list their own expenses', async () => {
    await seedExpense(OWNER_UID, 'e1');
    const db = ownerDb();
    await assertSucceeds(getDocs(collection(db, 'users', OWNER_UID, 'expenses')));
  });

  it('the owner can update their own expense', async () => {
    await seedExpense(OWNER_UID, 'e1');
    const db = ownerDb();
    await assertSucceeds(
      updateDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), {
        title: 'Updated title',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('the owner can delete their own expense', async () => {
    await seedExpense(OWNER_UID, 'e1');
    const db = ownerDb();
    await assertSucceeds(deleteDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1')));
  });

  it('a signed-in user cannot read another user\'s expense', async () => {
    await seedExpense(OWNER_UID, 'e1');
    const db = otherDb();
    await assertFails(getDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1')));
  });

  it('a signed-in user cannot list another user\'s expenses', async () => {
    await seedExpense(OWNER_UID, 'e1');
    const db = otherDb();
    await assertFails(getDocs(collection(db, 'users', OWNER_UID, 'expenses')));
  });

  it('a signed-in user cannot create an expense under another user\'s path', async () => {
    const db = otherDb();
    await assertFails(
      setDoc(
        doc(db, 'users', OWNER_UID, 'expenses', 'e1'),
        // Even with a userId field claiming to be the *victim* — the path
        // is what owner() checks, and OTHER_UID's token can never satisfy
        // request.auth.uid == 'owner-uid'.
        validExpense({ userId: OWNER_UID }),
      ),
    );
  });

  it('a signed-in user cannot spoof another user\'s ID in the userId field at their own path', async () => {
    const db = otherDb();
    await assertFails(
      setDoc(
        doc(db, 'users', OTHER_UID, 'expenses', 'e1'),
        validExpense({ userId: OWNER_UID }),
      ),
    );
  });

  it('a signed-in user cannot modify another user\'s expense', async () => {
    await seedExpense(OWNER_UID, 'e1');
    const db = otherDb();
    await assertFails(
      updateDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), {
        title: 'Hijacked',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('a signed-in user cannot delete another user\'s expense', async () => {
    await seedExpense(OWNER_UID, 'e1');
    const db = otherDb();
    await assertFails(deleteDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1')));
  });
});

describe('timestamps cannot be manipulated by the client', () => {
  it('rejects a create with a client-supplied createdAt instead of the server time', async () => {
    const db = ownerDb();
    await assertFails(
      setDoc(
        doc(db, 'users', OWNER_UID, 'expenses', 'e1'),
        validExpense({ createdAt: Timestamp.fromDate(new Date('2020-01-01T00:00:00Z')) }),
      ),
    );
  });

  it('rejects a create with a client-supplied updatedAt instead of the server time', async () => {
    const db = ownerDb();
    await assertFails(
      setDoc(
        doc(db, 'users', OWNER_UID, 'expenses', 'e1'),
        validExpense({ updatedAt: Timestamp.fromDate(new Date('2020-01-01T00:00:00Z')) }),
      ),
    );
  });

  it('rejects an update that tries to change createdAt', async () => {
    await seedExpense(OWNER_UID, 'e1');
    const db = ownerDb();
    await assertFails(
      updateDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), {
        createdAt: Timestamp.fromDate(new Date('2030-01-01T00:00:00Z')),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('rejects an update with a client-supplied updatedAt instead of the server time', async () => {
    await seedExpense(OWNER_UID, 'e1');
    const db = ownerDb();
    await assertFails(
      updateDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), {
        updatedAt: Timestamp.fromDate(new Date('2030-01-01T00:00:00Z')),
      }),
    );
  });
});

describe('the amount field cannot be manipulated out of bounds', () => {
  it('rejects a non-number amount', async () => {
    const db = ownerDb();
    await assertFails(
      setDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), validExpense({ amount: '12.50' })),
    );
  });

  it('rejects a zero amount', async () => {
    const db = ownerDb();
    await assertFails(
      setDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), validExpense({ amount: 0 })),
    );
  });

  it('rejects a negative amount', async () => {
    const db = ownerDb();
    await assertFails(
      setDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), validExpense({ amount: -5 })),
    );
  });

  it('accepts an amount exactly at the product ceiling', async () => {
    const db = ownerDb();
    await assertSucceeds(
      setDoc(
        doc(db, 'users', OWNER_UID, 'expenses', 'e1'),
        validExpense({ amount: 999999999.99 }),
      ),
    );
  });

  it('rejects an amount above the product ceiling', async () => {
    const db = ownerDb();
    await assertFails(
      setDoc(
        doc(db, 'users', OWNER_UID, 'expenses', 'e1'),
        validExpense({ amount: 1000000000 }),
      ),
    );
  });
});

describe('required fields and schema shape', () => {
  it('rejects a create missing a required field', async () => {
    const data = validExpense();
    delete data.category;
    const db = ownerDb();
    await assertFails(setDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), data));
  });

  it('rejects a create with an extra, unexpected field', async () => {
    const db = ownerDb();
    await assertFails(
      setDoc(
        doc(db, 'users', OWNER_UID, 'expenses', 'e1'),
        validExpense({ isPremiumExpense: true }),
      ),
    );
  });

  it('rejects a blank title', async () => {
    const db = ownerDb();
    await assertFails(
      setDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), validExpense({ title: '   ' })),
    );
  });

  it('rejects a title over the 120-character limit', async () => {
    const db = ownerDb();
    await assertFails(
      setDoc(
        doc(db, 'users', OWNER_UID, 'expenses', 'e1'),
        validExpense({ title: 'x'.repeat(121) }),
      ),
    );
  });

  it('rejects a note over the 300-character limit', async () => {
    const db = ownerDb();
    await assertFails(
      setDoc(
        doc(db, 'users', OWNER_UID, 'expenses', 'e1'),
        validExpense({ note: 'x'.repeat(301) }),
      ),
    );
  });

  it('accepts a create with no note field at all', async () => {
    const data = validExpense();
    const db = ownerDb();
    await assertSucceeds(setDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), data));
  });

  it('accepts a create with an explicit null note', async () => {
    const db = ownerDb();
    await assertSucceeds(
      setDoc(doc(db, 'users', OWNER_UID, 'expenses', 'e1'), validExpense({ note: null })),
    );
  });

  it('rejects an unrecognized category', async () => {
    const db = ownerDb();
    await assertFails(
      setDoc(
        doc(db, 'users', OWNER_UID, 'expenses', 'e1'),
        validExpense({ category: 'crypto' }),
      ),
    );
  });
});

describe('paths outside users/{uid}/expenses/* are denied by default', () => {
  it('cannot read or write the parent users/{uid} document', async () => {
    const db = ownerDb();
    await assertFails(getDoc(doc(db, 'users', OWNER_UID)));
    await assertFails(setDoc(doc(db, 'users', OWNER_UID), { anything: true }));
  });

  it('cannot read or write an unrelated top-level collection', async () => {
    const db = ownerDb();
    await assertFails(getDoc(doc(db, 'adminSettings', 'global')));
    await assertFails(setDoc(doc(db, 'adminSettings', 'global'), { anything: true }));
  });
});

// A quick sanity check that this file itself is wired up correctly even
// before any Firestore call runs, so a misconfigured emulator connection
// fails loudly rather than every test above silently erroring the same way.
describe('test environment sanity check', () => {
  it('initialized a test environment for this project', () => {
    assert.ok(testEnv, 'initializeTestEnvironment() must resolve before tests run');
  });
});
