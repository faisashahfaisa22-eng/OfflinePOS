# Required Android changes (the android/ folder was not in the uploaded source)

1. `android/app/src/main/AndroidManifest.xml` on `<application>`:
   * `android:allowBackup="false"`
   * `android:fullBackupContent="false"`
   * (optional) `android:usesCleartextTraffic="false"`
2. Optional but recommended: block screenshots / recents preview with `FLAG_SECURE` in `MainActivity`.
3. `android/app/build.gradle(.kts)`: `minSdk >= 24` (flutter_secure_storage / SQLCipher), change
   `applicationId` / `namespace` from `com.example.qamvio_pos` to your own id **before** publishing.
   NOTE: changing it makes Android treat it as a different app: data will not carry over.
4. Release signing: use a real upload keystore (as in the v15 GitHub workflow), never the debug key.
5. Run: `flutter pub get && flutter analyze && flutter test && flutter build apk --release`

# Data behaviour
* Existing plaintext `qamvio_pos.db` from earlier Flutter builds is encrypted on first sign-in
  (verified copy, then the plaintext file is deleted).
* The new local account is created fresh. v15 user accounts are not imported
  (their hashes live outside the encrypted data); the Admin recreates users.
* Importing the v15 cloud backup still works: Cloud & Backup > connect cloud account > Legacy migration.
* Old Flutter cloud backups were uploaded **unencrypted** (format 1). The first new backup
  overwrites that row with an encrypted one (format 2).
