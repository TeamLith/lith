# Lith Build + Release Guide

This project is configured so app display name is `Lith` on both iOS and macOS targets.

Workflow file:

- `.github/workflows/release-testflight.yml`

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

- `Apps/NativeNotesApp/Resources/Assets.xcassets/AppIcon.appiconset`

Current icon files are placeholders generated from the system generic app icon. Replace them with your brand assets before external testing/release.

Where to update:

1. Open `NativeNotes.xcworkspace` in Xcode.
2. Open `Assets.xcassets -> AppIcon`.
3. Drag your `Lith` icon images into all required slots.
4. Commit updated icon files in:
   - `Apps/NativeNotesApp/Resources/Assets.xcassets/AppIcon.appiconset/`

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
   - `com.nativenotes.ios`
   - `com.nativenotes.macos`
2. In App Store Connect, create both apps with those bundle IDs.
3. In App Store Connect -> Users and Access -> Keys:
   - Create API key (recommended role: App Manager).
   - Save `Key ID`, `Issuer ID`, `.p8` key.
4. In Xcode project signing, ensure your Team is selected for both targets when building locally.

## 5) Release flow (repeatable)

1. Merge changes to `main`.
2. Trigger `Release to TestFlight` workflow.
3. Wait for successful job(s).
4. Open App Store Connect -> TestFlight and assign builds to tester groups.

The workflow uploads `.ipa`/`.pkg` artifacts to the GitHub run as well.

## 6) Local device testing flow (Mac + iPhone)

Mac:

1. Xcode scheme: `NativeNotesmacOS`
2. Destination: `My Mac`
3. Run (`Cmd+R`)

iPhone:

1. Connect iPhone and enable Developer Mode.
2. Xcode scheme: `NativeNotesiOS`
3. Destination: your iPhone
4. Run (`Cmd+R`)
5. Trust the dev certificate on device if prompted.
