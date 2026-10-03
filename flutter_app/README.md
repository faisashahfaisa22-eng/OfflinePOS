# QAMVIO POS (Flutter)

Offline-first Flutter port of QAMVIO v15.

* Login: local, offline (email or mobile + password). Supabase is **not** used for login.
* Database: SQLCipher (AES-256). Key = random data key wrapped under each user's password and recovery code.
* Roles: Admin / Cashier / Salesman (rules ported from v15).
* Supabase: optional, **encrypted** cloud backup / restore only.

See `SECURITY_AND_ANDROID_NOTES.md` for the Android changes that must be applied to the `android/` folder.
