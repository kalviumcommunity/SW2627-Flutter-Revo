
const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const fs = require("fs");
const path = require("path");

const serviceAccount = require("./serviceAccountKey.json");

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

function readSeed(filename) {
  return JSON.parse(
    fs.readFileSync(
      path.join(__dirname, "firebase", "seed", filename),
      "utf8"
    )
  );
}

async function seedCollection(collectionName, filename, idField) {
  const records = readSeed(filename);
  const batch = db.batch();

  for (const record of records) {
    const { [idField]: id, ...data } = record;

    if (!id) {
      throw new Error(`Missing ${idField} in ${filename}`);
    }

    batch.set(db.collection(collectionName).doc(id), data);
  }

  await batch.commit();
  console.log(`Seeded ${records.length} documents into ${collectionName}`);
}

async function main() {
  await seedCollection("users", "users.json", "userId");
  await seedCollection("productions", "productions.json", "productionId");
  await seedCollection("venues", "venues.json", "venueId");

  console.log("All seed data uploaded successfully!");
}

main().catch((error) => {
  console.error("Seeding failed:", error.message);
  process.exitCode = 1;
});
