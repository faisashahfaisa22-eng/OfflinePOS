# QAMVIO License Activation (work in progress)
Base: release/flutter-play-v16-sarafi. This feature branch keeps POS and Sarafi intact.

## Confirmed integration points
- Flutter application: flutter_app/
- Entry point: flutter_app/lib/main.dart
- Existing offline local login: flutter_app/lib/core/security/local_auth_service.dart
- Existing cloud initialization: Supabase Flutter (backup use).
- Existing secure storage and cryptography dependencies.

## Security contract
1. Admin creates cryptographically random activation codes. Store only hashes in licenses.
2. Flutter sends code and installation identity to a Supabase Edge Function over HTTPS.
3. Edge Function atomically checks status, expiry, and active device count in a transaction, records attempts, and signs a short-lived entitlement with Ed25519 private key held only server-side.
4. Flutter verifies signature with pinned public key, installation binding, and expiry while offline. Store token and installation secret in secure storage; do not include in cloud backup.
5. On renewal, server can enforce revocation. Offline revocation is not instantaneous.
6. Never trust client-provided device count, expiry, or license status.
7. Install identity is not a tamper-proof hardware ID. Restored or compromised devices may require reactivation. Consider Android Keystore hardware-backed keys and Play Integrity as additional defenses.
8. Detect rollback using persisted last-seen time, but acknowledge it cannot fully prevent clock manipulation on compromised devices.

## Remaining implementation
- Atomic activation/revoke/renew Edge Functions and admin authorization
- Ed25519 signing key provisioning, public-key pinning and key rotation
- Flutter activation UI and startup gate integrated with existing offline login
- Renewal scheduling, test coverage, and migration policy for existing customers
- Deploy SQL and functions; test on actual Android devices

**Not yet deployed or enabled.** Never add service-role or private signing keys to Flutter or GitHub.
