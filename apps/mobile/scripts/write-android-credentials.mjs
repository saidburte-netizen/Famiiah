// Materialise Android signing credentials for `eas build` from environment
// secrets. Written to the app root as files that .gitignore excludes. Run from
// the mobile app directory (CI sets `working-directory: apps/mobile`).
//
// Required env vars:
//   ANDROID_KEYSTORE_BASE64    base64 of a .jks/.keystore (PKCS#12) file
//   ANDROID_KEYSTORE_PASSWORD  store password
//   ANDROID_KEY_ALIAS          key alias inside the keystore
//   ANDROID_KEY_PASSWORD       key password (usually the store password)
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const appRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const {
  ANDROID_KEYSTORE_BASE64,
  ANDROID_KEYSTORE_PASSWORD,
  ANDROID_KEY_ALIAS,
  ANDROID_KEY_PASSWORD,
} = process.env;

function fail(message) {
  console.error(`write-android-credentials: ${message}`);
  process.exit(1);
}

for (const [name, value] of Object.entries({
  ANDROID_KEYSTORE_BASE64,
  ANDROID_KEYSTORE_PASSWORD,
  ANDROID_KEY_ALIAS,
  ANDROID_KEY_PASSWORD,
})) {
  if (!value) fail(`${name} is not set`);
}

const base64 = ANDROID_KEYSTORE_BASE64.replace(/\s+/g, "");
const bytes = Buffer.from(base64, "base64");
if (bytes.length < 64) fail("decoded keystore is implausibly small");
// PKCS#12 / JKS files are DER; a PKCS#12 starts with a SEQUENCE (0x30 0x82).
if (bytes[0] !== 0x30) fail("decoded keystore does not look like PKCS#12/JKS (DER)");

const keystorePath = join(appRoot, "android-upload.keystore");
writeFileSync(keystorePath, bytes);

const credentials = {
  android: {
    keystore: {
      keystorePath: "android-upload.keystore",
      keystorePassword: ANDROID_KEYSTORE_PASSWORD,
      keyAlias: ANDROID_KEY_ALIAS,
      keyPassword: ANDROID_KEY_PASSWORD,
    },
  },
};
mkdirSync(appRoot, { recursive: true });
writeFileSync(join(appRoot, "credentials.json"), `${JSON.stringify(credentials, null, 2)}\n`);

console.log(
  `write-android-credentials: wrote android-upload.keystore (${bytes.length} bytes) and credentials.json`,
);
