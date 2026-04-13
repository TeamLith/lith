# Lith Build + Release Guide

This guide is for human operators handling signing, secrets, and TestFlight/App Store release steps. Start with `HUMANS.md` for local setup and validation, then use this file for release-specific configuration.

This project is configured so app display name is `Lith` on both iOS and macOS targets.

Workflow file:

- `.github/workflows/release-testflight.yml`
- `.github/workflows/validate.yml`

Run from GitHub:

- **GitHub -> Actions -> Release to TestFlight -> Run workflow**

Choose:

- `ios`, `macos`, or `both`
- Internal-only TestFlight upload on/off

## 1) App name status

Already configured in project settings:

- iOS target `INFOPLIST_KEY_CFBundleDisplayName = Lith`
- macOS target `INFOPLIST_KEY_CFBundleDisplayName = Lith`
- iOS/macOS target `PRODUCT_NAME = Lith`

Note:

- The App Store listing name is controlled in App Store Connect (`App Information -> Name`), and should also be set to `Lith`.

## 2) App icon status and where to change it

Asset catalog is now wired in both targets:

- `Apps/LithApp/Resources/Assets.xcassets/AppIcon.appiconset`

Current icon files are placeholders generated from the system generic app icon. Replace them with your brand assets before external testing/release.

Where to update:

1. Open `Lith.xcworkspace` in Xcode.
2. Open `Assets.xcassets -> AppIcon`.
3. Drag your `Lith` icon images into all required slots.
4. Commit updated icon files in:
   - `Apps/LithApp/Resources/Assets.xcassets/AppIcon.appiconset/`

Also in App Store Connect:

- App Store listing icon is taken from uploaded build (the 1024 marketing icon in `AppIcon` set).

## 3) Required GitHub secrets

In **GitHub -> Settings -> Secrets and variables -> Actions**, add:

- `APPLE_TEAM_ID`
  - Your Apple Developer Team ID (10 chars)
- `APP_STORE_CONNECT_KEY_ID`
  - API Key ID from App Store Connect
- `APP_STORE_CONNECT_ISSUER_ID`
  - Issuer ID from App Store Connect API keys page
- `APP_STORE_CONNECT_PRIVATE_KEY`
  - Full text contents of `AuthKey_<KEY_ID>.p8` (including BEGIN/END lines)

## 4) Apple-side one-time setup

1. In Apple Developer, ensure App IDs exist and match bundle IDs:
   - `me.lith.ios`
   - `me.lith.macos`
2. In App Store Connect, create both apps with those bundle IDs.
3. In App Store Connect -> Users and Access -> Keys:
   - Create API key (recommended role: App Manager).
   - Save `Key ID`, `Issuer ID`, `.p8` key.
4. In Xcode project signing, ensure your Team is selected for both targets when building locally.

## 5) Release flow (repeatable)

1. Merge changes to `main` only after the `Validate` workflow passes.
2. Trigger `Release to TestFlight` workflow.
3. Wait for the `Preflight validation` job and the selected release job(s) to succeed. The workflow now serializes same-ref release runs so two manual dispatches do not archive/upload from the same branch at the same time.
4. Open App Store Connect -> TestFlight and assign builds to tester groups.

The release workflow regenerates `LithApps.xcodeproj` from `project.yml` before archiving, uploads `.ipa`/`.pkg` artifacts for successful runs, and uploads validation or archive/export logs when a run fails.

## 6) Validation workflow

Before a manual release, the repo now uses a shared validation path:

1. Local validation: run `scripts/validate.sh`.
2. CI validation: the `Validate` workflow runs on pull requests and pushes to `main`, cancels superseded same-ref runs, and uses an explicit job timeout so stalled macOS jobs do not consume the default six-hour window.
3. Release validation: the `Release to TestFlight` workflow blocks on the same validation script before archiving, serializes same-ref dispatches, and fails if regenerating `LithApps.xcodeproj` would introduce uncommitted generated changes.

This keeps Swift package checks, XcodeGen project generation, and iOS/macOS app builds aligned across local work, CI, and release automation.

## 7) Local device testing flow (Mac + iPhone)

Mac:

1. Xcode scheme: `LithmacOS`
2. Destination: `My Mac`
3. Run (`Cmd+R`)

iPhone:

1. Connect iPhone and enable Developer Mode.
2. Xcode scheme: `LithiOS`
3. Destination: your iPhone
4. Run (`Cmd+R`)
5. Trust the dev certificate on device if prompted.
