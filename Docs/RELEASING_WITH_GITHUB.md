# Releasing with GitHub Actions

This repo includes a manual workflow at:

- `.github/workflows/release-testflight.yml`

You can trigger it from **GitHub -> Actions -> Release to TestFlight -> Run workflow** and choose `ios`, `macos`, or `both`.

## One-time setup

Add these repository secrets in **GitHub -> Settings -> Secrets and variables -> Actions**:

- `APPLE_TEAM_ID`: your Apple Developer Team ID (10 characters)
- `APP_STORE_CONNECT_KEY_ID`: API key ID from App Store Connect
- `APP_STORE_CONNECT_ISSUER_ID`: issuer ID from App Store Connect
- `APP_STORE_CONNECT_PRIVATE_KEY`: full contents of `AuthKey_<KEY_ID>.p8`

## App Store Connect prerequisites

- Create app records in App Store Connect for:
  - `com.nativenotes.ios`
  - `com.nativenotes.macos`
- Grant the API key permission to upload builds.
- Ensure bundle IDs/capabilities are valid for App Store distribution.

## Typical release flow

1. Merge to `main`.
2. Open the workflow and run it for `both`.
3. Wait for successful jobs.
4. In App Store Connect -> TestFlight, assign testers/groups.

The workflow also uploads the exported `.ipa`/`.pkg` as GitHub artifacts for each run.
