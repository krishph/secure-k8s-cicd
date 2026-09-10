# Policy behavior and boundaries

`policies/kubernetes.rego` uses Rego v1 and Conftest's default `main` namespace.
Input files are evaluated individually; do not add `--combine`, which changes
the input shape. `walk` discovers supported workload objects inside a Kubernetes List.

The image allowlist compares **exact repositories**, not broad registry prefixes.
Add your own fully qualified ECR/GHCR repository names to `approved_repositories`.
The three defaults are example application repositories and Docker's Redis image.
Allowlisting a repository does not establish ownership, signature validity, or
trustworthiness. There are no application images published by this prototype.

SC001 accepts tags or lowercase 64-character SHA256 digests. Implicit `latest`,
explicit `latest` (including `latest@sha256:...`), and malformed references are denied.
Registry ports and custom image-reference syntaxes are intentionally unsupported.
Tags can move. Use digest references for a release to prevent the scanned and
deployed image from differing after a tag changes.

SC003 checks presence/nonempty CPU and memory declarations, not Kubernetes quantity
semantics or whether requests are less than limits. It is not a capacity calculator.
String values such as `"0"` are outside its numeric validation scope. Kubernetes
server dry-run validates API semantics before the supplied deployment script applies.

SC006 resolves container overrides before Pod defaults. A nonzero numeric UID is
set in every sample workload, while the rule permits an unspecified UID if effective
`runAsNonRoot` is true (Kubernetes then checks the image at runtime).

The fixtures seed ten independent mistakes: latest tag, omitted tag, unapproved
repository, four missing resource fields, privileged mode, privilege escalation,
and UID 0. Additional Rego tests cover digest references, repository lookalikes,
controller wrappers, CronJobs/Lists, and init/ephemeral containers. These tests
have been authored but not executed.

This policy pack does not enforce the full Kubernetes Restricted Pod Security
Standard, CIS compliance, schema correctness, all volume types, capabilities, custom
resource workloads, RBAC, signatures, secrets, or runtime behavior. The sample
namespace enables Kubernetes Restricted Pod Security admission separately. The
sample manifests also drop capabilities and use RuntimeDefault seccomp, but those
settings are not independently required by this Rego pack.

CI sees the PR's policies and workflow, so a contributor can propose weakening them.
Use required review of policy/workflow changes and branch rules. For stronger
organizational enforcement, run policies from an independently protected source
and add runtime admission controls such as Gatekeeper or Kyverno.
