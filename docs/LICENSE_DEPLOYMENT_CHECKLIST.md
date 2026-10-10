# License deployment checklist

1. Configure a server-only Ed25519 signing key and publish the corresponding public key in Flutter.
2. Implement and deploy an authenticated activation and renewal endpoint.
3. Ensure atomic device-limit enforcement and admin-only device revocation.
4. Add a startup activation gate without affecting existing customers until rollout.
5. Test expiry, backup restore, revoked devices, clock rollback, and offline use.

Do not embed private keys or privileged database credentials in mobile code.
