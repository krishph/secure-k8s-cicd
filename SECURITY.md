# Security

This is an educational, unexecuted prototype, not a production security product
or a claim of CIS compliance. See `docs/policies.md` for enforcement boundaries.
The voting app has no authentication, rate limiting, durable storage, or TLS.
Keep it on localhost or a private demo cluster.

For a public fork, enable GitHub private vulnerability reporting under repository
security settings and use that channel for sensitive reports. Use ordinary issues
for non-sensitive bugs. Do not include credentials or exploitable private-system
details in public issues.

Before production use, review and execute the tests, scan dependencies, pin release
images by digest, use a maintained Kubernetes version, protect policy changes,
and integrate organization-specific runtime admission and identity controls.
