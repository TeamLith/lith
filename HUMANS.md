# Human Operator Guide

Use this file for local setup, day-to-day development, and release steps that require a real machine, Apple credentials, signing, or approval. Autonomous implementation agents should start with `AGENTS.md` instead.

## Start Here

1. Read `README.md` for the product summary and spec index.
2. Read `REPO_MAP.md` for repository layout, entry points, and canonical build/test commands.
3. Read only the feature or sync specs that match the work you are doing.
4. Use `CONTRIBUTING_AGENTS.md` when coordinating with agents or claiming a tracked task.
5. Use `Docs/RELEASING_WITH_GITHUB.md` for TestFlight and App Store release setup.

## One-Time Setup Checklist

- Install a current Xcode release with the bundled Swift toolchain and Command Line Tools enabled.
- Install XcodeGen so `project.yml` can regenerate `LithApps.xcodeproj`.
- Clone the repository and confirm you can run `swift build` and `swift test`.
- Open `Lith.xcworkspace` or `LithApps.xcodeproj` in Xcode for app work.
- Select your Apple Developer Team for both app targets before local device or archive builds.
- Complete the Apple and GitHub credential setup in `Docs/RELEASING_WITH_GITHUB.md` before attempting TestFlight uploads.

## Daily Development Workflow

1. Start with `README.md`, `REPO_MAP.md`, and the relevant spec documents.
2. If the work is tracked, keep exactly one task current in `CONTRIBUTING_AGENTS.md`.
3. Prefer changes under `Sources/Lith` unless the work is truly app-shell-specific.
4. Treat `project.yml` as the source of truth for target structure and regenerate the Xcode project after structural changes.
5. Run `scripts/validate.sh` before merging, handing work to an agent, or triggering a release. It regenerates the Xcode project and runs the package plus app build validations. CI and release automation additionally fail if regeneration would change committed `LithApps.xcodeproj` files.

## Canonical Commands

```bash
scripts/validate.sh
xcodegen generate
swift build
swift test
xcodebuild -scheme LithmacOS -project LithApps.xcodeproj -configuration Debug -destination 'platform=macOS' build
xcodebuild -scheme LithiOS -project LithApps.xcodeproj -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

## Humans vs Agents

- Humans own machine-local setup, tool installation, Apple signing, App Store Connect access, GitHub secrets, device provisioning, and final release approval.
- Agents may implement one scoped task at a time, update repo docs and task metadata, run local validation, and bump versions when a tracked task is completed.
- Humans should intervene when work requires credentials, legal or license judgment, Apple account changes, or any setup input an agent cannot discover safely.
- Agents should not invent secrets, signing identities, team IDs, or release metadata that only a human can provide.

## Working With Agents

- Point implementation agents at `AGENTS.md` and ask them to follow the repo task workflow.
- Use `CONTRIBUTING_AGENTS.md` as the shared task board and pause/resume log.
- Review agent branches or commits before merging, especially when version bumps or workflow docs changed.
- If an agent reports a blocker tied to credentials or signing, resolve that input as a human and then resume the task.

## Triggering A Repo Self-Improvement Run

- Ask explicitly for a repo self-improvement run, for example:
  `Run a repo self-improvement pass per AGENTS.md. Audit the workflow against current best practices, use current primary sources, make bounded improvements, and avoid product feature work.`
- This run type is separate from the normal first-`TODO` task flow and is intended for improving repo instructions, validation, CI, release process, and repo-local skill guidance.
- Expect the agent to keep the run bounded, cite or summarize current primary-source guidance when recommendations are time-sensitive, and add follow-up `TODO` tasks for larger work instead of expanding scope silently.
- Review the resulting branch or diff like any other process change, especially if it alters validation, release workflow, or contributor instructions.

## Release Flow

1. Merge approved changes to `main` after the `Validate` GitHub Actions workflow passes.
2. Trigger the `Release to TestFlight` GitHub Actions workflow. The release workflow reruns preflight validation and regenerates `LithApps.xcodeproj` from `project.yml` before archiving.
3. Verify the uploaded build in App Store Connect and assign it to tester groups.
4. Keep `Docs/RELEASING_WITH_GITHUB.md` as the detailed source for release prerequisites and Apple-side setup.
