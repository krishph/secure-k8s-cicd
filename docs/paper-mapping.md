# Relationship to the paper

Source: Hari Krishna Pokala, *A Secure CI/CD Pipeline using GitHub Actions and Open
Policy Agent (OPA) for Kubernetes Applications*, provided as `a73-pokala final.pdf`.
No publication venue or DOI is inferred. This repository is a new implementation
based on the design, not an assertion that it is the original experimental source.

| Paper concept | Prototype implementation |
| --- | --- |
| Frontend/backend/Redis voting sample | `app/`, `compose.yaml`, `k8s/`, Helm chart |
| Pull-request and main checks | `.github/workflows/secure-k8s-cicd.yaml` |
| OPA/Conftest policy gate | Rego v1 policies and `scripts/check.sh` |
| Raw and Helm manifest validation | Render Helm to a file and test both inputs |
| Latest tags, registries, privileges, resources | SC001–SC004; SC005–SC008 extend the paper |
| Optional vulnerability scan | Required by this prototype's CI; scans all three images |
| Deployment after enforcement | Explicit operator-run gated deployment script |
| EKS/ECR and IRSA | Optional setup guidance; not provisioned or empirically validated |
| Actionable developer feedback | Check logs and job summary; no PR comment bot |
| Ten seeded violations | Ten illustrative negative fixtures, not the paper's original dataset |

Implementation corrections: OPA setup alone does not install Conftest. This prototype
invokes a Conftest container directly. Helm YAML is written to a file before Conftest
reads it; it is not substituted into a list of filename arguments. CI has no path
filters, so changes to policies, app code, scripts, or workflow logic are checked too.

The paper reports 20 runs, 100% detection of ten seeded violations, no observed false
positives, and an average increase from 85 to 99 seconds. None of those measurements
has been reproduced here. A future evaluation should record tool versions, commit
SHA, runner hardware, warm/cold image and database caches, fixture definitions,
wall-clock durations, and raw check outcomes. Compare otherwise identical baseline
and policy-enabled workflows; container downloads can dominate cold-run overhead.
