# Publish this folder to GitHub

The folder is prepared as a repository, but Git initialization, commits, remote
creation, and publication are left for you. Run these commands only when ready.
The source paper remains local because `*.pdf` is ignored. The MIT license applies
to newly authored code/docs, not the paper or bundled third-party software.

```bash
git init -b main
git add .
git diff --cached --stat
git diff --cached
git commit -m "Add SecureCICD policy-as-code prototype"

# Requires the GitHub CLI and an authenticated account.
gh auth login
gh repo create SecureCICD --public --source=. --remote=origin --push
```

The initial push activates the supplied workflow on GitHub. If you already have
an empty GitHub repository, substitute your actual remote and use:

```bash
git remote add origin https://github.com/YOUR_USERNAME/SecureCICD.git
git push -u origin main
```

After the workflow has run, configure a branch ruleset for `main` (and `develop`/
`staging` if used): require pull requests, review, and the **Security gate** status
check, and prevent bypasses appropriate to your project. Require trusted review
for `.github/`, `policies/`, and `scripts/`; add a CODEOWNERS file with your actual
maintainer handles if desired. There are no fabricated owners in this template.

The workflow intentionally uses `pull_request`, not `pull_request_target`, and
does not use secrets, cloud credentials, write permissions, or a PR comment bot.
Fork PRs may need maintainer approval to start Actions under your repository settings.
Dependency update PRs are configured for Python, Dockerfiles, and Actions. Review
tool image versions in `scripts/tools.sh`, Compose, Helm, and raw YAML manually.
