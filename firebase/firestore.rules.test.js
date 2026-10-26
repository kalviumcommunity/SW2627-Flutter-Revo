const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require("firebase/firestore");
const fs = require("fs");
const path = require("path");

const projectId = "revo-theatre-management";
const rules = fs.readFileSync(
  path.join(__dirname, "..", "firestore.rules"),
  "utf8",
);

let testEnv;

const user = (uid, role) => ({
  userId: uid,
  name: `${role} User`,
  email: `${uid}@example.com`,
  role,
  createdAt: "2026-10-01T00:00:00.000Z",
});

const production = (id, directorId) => ({
  productionId: id,
  name: "The Crucible",
  description: "A production",
  directorId,
  startDate: "2026-10-01T00:00:00.000Z",
  endDate: "2026-12-01T00:00:00.000Z",
  status: "planning",
  createdAt: "2026-10-01T00:00:00.000Z",
  updatedAt: "2026-10-01T00:00:00.000Z",
});

const venue = (id) => ({
  venueId: id,
  name: "Studio A",
  location: "Arts Wing",
  capacity: 45,
  availability: { available: true },
  status: "active",
});

const rehearsal = (id, productionId, createdBy) => ({
  rehearsalId: id,
  productionId,
  venueId: "venue-1",
  startAt: "2026-10-20T10:00:00.000Z",
  endAt: "2026-10-20T12:00:00.000Z",
  participantIds: ["cast-1"],
  status: "confirmed",
  clientPending: false,
  createdBy,
  createdAt: "2026-10-01T00:00:00.000Z",
  updatedAt: "2026-10-01T00:00:00.000Z",
});

function context(uid, role) {
  return testEnv.authenticatedContext(uid, { role });
}

async function assertSucceeds(operation) {
  await operation;
}

async function assertFails(operation) {
  let failed = false;
  try {
    await operation;
  } catch (_) {
    failed = true;
  }
  if (!failed) {
    throw new Error("Expected Firestore operation to be denied.");
  }
}

async function main() {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
  await testEnv.withSecurityRulesDisabled(async (adminContext) => {
    const adminDb = adminContext.firestore();
    await setDoc(doc(adminDb, "users", "admin-1"), user("admin-1", "ADMIN"));
    await setDoc(doc(adminDb, "users", "director-1"), user("director-1", "DIRECTOR"));
    await setDoc(doc(adminDb, "users", "director-2"), user("director-2", "DIRECTOR"));
    await setDoc(doc(adminDb, "users", "cast-1"), user("cast-1", "CAST_MEMBER"));
    await setDoc(doc(adminDb, "productions", "production-1"), production("production-1", "director-1"));
    await setDoc(doc(adminDb, "productions", "production-2"), production("production-2", "director-2"));
    await setDoc(doc(adminDb, "venues", "venue-1"), venue("venue-1"));
  });

  const unauthenticated = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(unauthenticated, "productions", "production-1")));
  await assertFails(setDoc(doc(unauthenticated, "venues", "venue-new"), venue("venue-new")));

  const director = context("director-1", "DIRECTOR").firestore();
  await assertSucceeds(getDoc(doc(director, "productions", "production-1")));
  await assertSucceeds(updateDoc(doc(director, "productions", "production-1"), {
    description: "Updated",
    updatedAt: "2026-10-02T00:00:00.000Z",
  }));
  await assertFails(updateDoc(doc(director, "productions", "production-2"), {
    description: "Unauthorized",
  }));

  const admin = context("admin-1", "ADMIN").firestore();
  await assertSucceeds(setDoc(doc(admin, "venues", "venue-new"), venue("venue-new")));
  await assertSucceeds(updateDoc(doc(admin, "venues", "venue-new"), { capacity: 60 }));
  await assertSucceeds(deleteDoc(doc(admin, "venues", "venue-new")));
  await assertFails(setDoc(doc(director, "venues", "venue-denied"), venue("venue-denied")));
  await assertFails(setDoc(doc(admin, "venues", "venue-invalid"), {
    ...venue("venue-invalid"),
    capacity: -1,
  }));

  const otherDirector = context("director-2", "DIRECTOR").firestore();
  const cast = context("cast-1", "CAST_MEMBER").firestore();
  await assertSucceeds(setDoc(
    doc(director, "rehearsals", "rehearsal-1"),
    rehearsal("rehearsal-1", "production-1", "director-1"),
  ));
  await assertFails(setDoc(
    doc(otherDirector, "rehearsals", "rehearsal-2"),
    rehearsal("rehearsal-2", "production-1", "director-2"),
  ));
  await assertFails(setDoc(
    doc(cast, "rehearsals", "rehearsal-3"),
    rehearsal("rehearsal-3", "production-1", "cast-1"),
  ));
  await assertFails(setDoc(
    doc(director, "rehearsals", "rehearsal-invalid"),
    { ...rehearsal("rehearsal-invalid", "production-1", "director-1"), participantIds: "cast-1" },
  ));
  await assertSucceeds(updateDoc(doc(director, "rehearsals", "rehearsal-1"), {
    status: "cancelled",
    updatedAt: "2026-10-02T00:00:00.000Z",
  }));
  await assertSucceeds(deleteDoc(doc(director, "rehearsals", "rehearsal-1")));
  console.log("Firebase security rules tests passed.");
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });
