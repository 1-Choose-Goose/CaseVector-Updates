# CaseVector updates

This public repository publishes signed Windows updates. The application source stays in the private [FSIN-Navigator-Pro](https://github.com/1-Choose-Goose/FSIN-Navigator-Pro) repository. The application's update URL and release file names remain unchanged.

The [release workflow](.github/workflows/release.yml) runs on standard GitHub hosted `windows-latest` runners. It checks for the newest version tag on private `main` every six hours and may also be started manually by `1-Choose-Goose`. It runs the private project's tests and build, checks the ZIP and Ed25519 signature against the existing public key, then uploads the four update files directly to a draft release and publishes it. The private source, build logs, and intermediate folders are not uploaded as Actions artifacts or cached. Pull requests and pushes do not trigger this workflow. A monthly empty commit keeps GitHub's scheduled workflow active when no versions are released for 60 days; it contains no source or build output.

## Repository credentials

The two **Actions repository secrets** in this public repository are:

1. `CASEVECTOR_SOURCE_DEPLOY_KEY`: a GitHub deploy key registered only on the private `FSIN-Navigator-Pro` repository with **read-only** access. The public half is registered there; the private half is kept only as this repository's Actions secret and the owner's local backup. Unlike a personal access token, this repository-specific credential can be provisioned with the existing GitHub admin API and does not require broader account access or periodic renewal.
2. `CASEVECTOR_ED25519_PRIVATE_KEY`: the new signing key generated for v1.2.9. Its public key is pinned in the release verifier and the application. The private value must never be committed.

Manage these values at [CaseVector-Updates Actions secrets](https://github.com/1-Choose-Goose/CaseVector-Updates/settings/secrets/actions). Never add them to an issue, commit, workflow input, log, or chat. The workflow checks that the signing key matches the pinned public trust key before it publishes anything.

Start [Publish signed CaseVector update](https://github.com/1-Choose-Goose/CaseVector-Updates/actions/workflows/release.yml) with **Run workflow** on `main`. Later source version tags are picked up by the six-hour schedule. The computer does not need to stay on. GitHub Actions on public repositories with standard GitHub hosted runners are free under GitHub's published pricing rules.

**Upgrade from v1.2.8:** The installed v1.2.8 trusts only the previous signing key and cannot authenticate v1.2.9 signed by the new key. Follow the [manual upgrade instructions](MANUAL-UPGRADE.md), keeping the existing `data` folder beside `CaseVector.exe`. Once v1.2.9 is installed, later updates signed with the new key can use the automatic updater.
