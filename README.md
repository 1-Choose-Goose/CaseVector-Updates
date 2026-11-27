# CaseVector updates

This public repository publishes signed Windows updates. The application source stays in the private [FSIN-Navigator-Pro](https://github.com/1-Choose-Goose/FSIN-Navigator-Pro) repository. The application's update URL and release file names remain unchanged.

The [release workflow](.github/workflows/release.yml) runs on a standard GitHub hosted `windows-latest` runner. It checks for the newest version tag on private `main` every hour and may also be started manually by `1-Choose-Goose`. It runs the private project's tests and build, checks the ZIP and Ed25519 signature against the existing public key, then uploads the four update files directly to a draft release and publishes it. The private source, build logs, and intermediate folders are not uploaded as Actions artifacts or cached. Pull requests and pushes do not trigger this workflow.

## One-time repository secrets

The owner must set two **Actions repository secrets** in this public repository:

1. `CASEVECTOR_SOURCE_READ_TOKEN`: a fine-grained personal access token owned by `1-Choose-Goose`, with access to **only** `FSIN-Navigator-Pro` and repository **Contents: Read-only** permission. Create it at [GitHub personal access tokens](https://github.com/settings/personal-access-tokens/new). Set a suitable expiration and renew it before it expires.
2. `CASEVECTOR_ED25519_PRIVATE_KEY`: the **existing** signing key value used for v1.2.8, unchanged. GitHub does not reveal the value of an existing Actions secret, so use the original secure copy. Do not generate a replacement.

Add both values at [CaseVector-Updates Actions secrets](https://github.com/1-Choose-Goose/CaseVector-Updates/settings/secrets/actions/new). Never add them to a file, issue, commit, workflow input, log, or chat. The workflow checks that the signing key matches the existing public trust key before it publishes anything.

Once both secrets exist, start [Publish signed CaseVector update](https://github.com/1-Choose-Goose/CaseVector-Updates/actions/workflows/release.yml) with **Run workflow** on `main`. Later source version tags are picked up by the hourly schedule. The computer does not need to stay on. GitHub Actions on public repositories with standard GitHub hosted runners are free under GitHub's published pricing rules.
