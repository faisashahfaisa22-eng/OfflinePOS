Offline POS & Accounts Pro — Play Store Release Build
=====================================================

Package: com.offlinepos.accounts
Version name: 8.0.2
Version code: 1
minSdk: 26
targetSdk: 36
compileSdk: 36
Release artifact: app-release.aab
Signing alias: offlinepos

WHAT IS ALREADY PREPARED
- Full Android app project under app/src/main/
- Play Store release Gradle configuration
- API 36 target configuration
- GitHub Actions workflow: .github/workflows/build-release-aab.yml
- Release signing reads secrets only; no keystore/password is committed
- allowBackup=false for local POS/accounting data
- cleartext HTTP disabled
- Embedded emergency-pack version string updated to 8.0.2

GITHUB BUILD
1. Put the files from this project into the OfflinePOS repository main branch.
2. In GitHub: Settings > Secrets and variables > Actions > New repository secret.
3. Add ANDROID_KEYSTORE_BASE64 and ANDROID_KEYSTORE_PASSWORD from the separate secrets file.
4. Open Actions > Build Play Store AAB > Run workflow.
5. Download artifact: OfflinePOS-PlayStore-AAB-v8.0.2.
6. Inside it is app-release.aab for Google Play Console.

SECURITY
Keep offlinepos-upload.jks permanently. Never commit it to GitHub.
