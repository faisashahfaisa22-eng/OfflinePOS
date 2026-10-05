# QAMVIO Chrome / Laptop PWA

This branch adds an installable Flutter Web version of QAMVIO POS for Chrome on
laptops.

## Local data security

QAMVIO does **not** fall back to an unencrypted browser database.

- Android/iOS keep the existing SQLCipher database driver.
- Web uses `sqflite_common_ffi_web` backed by `sqlite3mc.wasm`
  (SQLite3 Multiple Ciphers).
- The web driver selects the SQLCipher cipher and uses the same 256-bit QAMVIO
  data-encryption key format before the schema is read.
- The SQLite file is persisted by the web database worker in browser IndexedDB.
- A Chrome runtime smoke test writes data, closes the database, verifies that a
  different key cannot read it, and then reopens it with the original key.

The WebAssembly file is pinned to sqlite3 2.9.4 and its SHA-256 is verified by
CI before tests/builds.

## Offline behavior

Flutter's generated web service worker is included in the release build and
caches the application shell/assets. CI verifies that the final service worker
contains the QAMVIO database WASM and database worker resources.

Browser local credentials use `flutter_secure_storage`'s web implementation.
Production hosting must use HTTPS.

## Cloud backup

Manual encrypted cloud backup/restore continues to use the existing QAMVIO
AES-GCM backup envelope. The PWA does not rely on Workmanager for scheduled
background execution because browsers may suspend background work. Native
Android/iOS scheduling remains unchanged.

## Install

After the PWA is hosted over HTTPS, Chrome can install it as a standalone app
from the browser's install control. It is intended for Windows, macOS and Linux
laptops running a current Chrome/Chromium browser.
