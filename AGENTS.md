# AGENTS.md

Notes for AI coding agents working on the FlutterFire CLI. User docs: `README.md`. Contribution rules: `CONTRIBUTING.md`.

## Layout

Dart pub workspace managed by melos 7. The melos config sits under `melos:` in the root `pubspec.yaml`; there is no `melos.yaml`.

- `packages/flutterfire_cli/`: the `flutterfire` CLI published on pub.dev. Entry point: `bin/flutterfire.dart`.
- `packages/flutterfire_starter/`: a mason brick (`brick.yaml`, mustache templates in `__brick__/`) plus `hooks/` (package `flutterfire_starter_hooks`). `hooks/post_gen.dart` imports `flutterfire_cli/src/command_runner.dart` and `src/flutter_app.dart`, so changing those APIs can break the hooks.
- `bin/flutterfire_dev.dart`: root dev executable, exposed as `flutterfire` by the root pubspec. It wraps the CLI and prints a "local development version" banner on `--help`.
- `scripts/generate_version.dart`: writes `packages/flutterfire_cli/lib/version.g.dart` from the package version.

## Code map (`packages/flutterfire_cli/lib/src/`)

- `command_runner.dart`: `FlutterFireCommandRunner` registers every command. `commands/base.dart` adds the shared `--project`, `--account` and `--debug` options.
- `commands/`: `config.dart` (`configure`, aliases `c`/`config`), `reconfigure.dart`, `install.dart` (installs plugins from a BoM version), `update.dart`, `upload_symbols.dart` (`upload-crashlytics-symbols`) and `bundle_service_file.dart` (`bundle-service-file`). The last two are hidden and run from Xcode build phases, so `bin/flutterfire.dart` skips loading the Flutter app for them.
- `common/`
  - `prompts/`: Android, Apple and Dart-file prompts.
  - `validation.dart`: turns flags and prompt answers into `*Inputs`.
  - `strings.dart`: user-facing messages, constants such as `kIos`, and the `FlutterFireException` subclasses.
  - `utils.dart`: prompt helpers, `isCI`, path helpers, `firebase.json` writes (`writeToFirebaseJson`), Xcode/Ruby helpers and ID validators.
  - `platform.dart`: `currentPlatform`, which tests can stub through a zone.
- `firebase/`: per-platform options (`firebase_*_options.dart`) and the writers that patch the user's app:
  - `firebase_android_writes.dart`: Gradle files, Groovy and Kotlin DSL.
  - `firebase_apple_writes.dart`: the Xcode project.
  - `firebase_web_writes.dart`: `web/firebase-messaging-sw.js`.
  - `firebase_dart_configuration_write.dart`: `firebase_options.dart`.
- `firebase.dart`: wraps the `firebase` CLI (firebase-tools). `runFirebaseCommand` adds `--json`, and `firebaseCLIJsonParse` parses the output.
- `flutter_app.dart`: `FlutterApp.load` reads the app's pubspec, detected platforms and bundle IDs.

## Setup and running locally

```bash
dart pub get                                # at the repo root: resolves the whole workspace
dart run bin/flutterfire_dev.dart --help    # run the CLI from source, no install
dart pub global activate --source="path" . --executable="flutterfire" --overwrite
flutterfire --help                          # banner confirms the local build
```

Run commands from inside a Flutter app directory. If the global `flutterfire` doesn't pick up your edits, delete `.dart_tool/pub/bin/flutterfire_cli_monorepo/*.snapshot` and activate again.

The melos scripts call `melos exec`, so `melos` must be on `PATH`: run `dart pub global activate melos 7.5.1` (the version CI uses). Without it, use the plain commands below.

## Verify your change

| Check | melos | Without melos |
| --- | --- | --- |
| Analyze | `melos run analyze --no-select` | `dart analyze --fatal-infos` (at the root, covers every package) |
| Format | `melos run format-check --no-select` | `dart format --output=none --set-exit-if-changed packages/flutterfire_cli packages/flutterfire_starter/hooks bin scripts` |
| Offline tests (default) | `melos run test:unit --no-select` | `cd packages/flutterfire_cli && dart test --exclude-tags e2e` |
| End-to-end tests | `melos run test:e2e --no-select` | `cd packages/flutterfire_cli && dart test --tags e2e` |

- `format-check` runs `dart format` in place, one file at a time, and always exits 0 (`find -exec ... \;`). Check `git diff` afterwards, or use the dry-run command, which fails on changes. `format-check` skips files named `firebase_options.dart`. Never format or analyze `__brick__/`: the mustache templates are not valid Dart.
- Run tests from `packages/flutterfire_cli`, because `dart_test.yaml` (which declares the `e2e` tag) and the golden path are relative to it. To run one test: `dart test test/unit_test.dart -N "configure --display-name"`.
- The offline suite runs in seconds with no network. Keep new tests offline (temp dirs, fakes like `update_test.dart`) whenever possible.
- The `e2e` tests (`configure_test.dart`, `reconfigure_test.dart`, `install_test.dart`) need all of these, so agents usually can't run them:
  - the `flutterfire` on `PATH`. They don't use your source, so activate again after editing.
  - `flutter`, network access, and firebase-tools signed in to `flutterfire-cli-test-f6f57` (`FIREBASE_TOKEN` or `firebase login`).
  - on macOS only: Xcode and the Ruby `xcodeproj` gem.

  Each test runs `flutter create`, so a full run takes many minutes. To mark a new test that hits the network or Firebase, use `@Tags(['e2e'])` + `library;` at the top of the file, or `tags: 'e2e'` on a single test.
- On CI, `.github/workflows/test.yaml` runs `melos run test --no-select` (offline and e2e) on Linux, macOS and Windows. It runs only when the triggering user has write access; for anyone else the job fails.

## Generated files: do not edit by hand

- `packages/flutterfire_cli/lib/version.g.dart`: regenerated by `dart run scripts/generate_version.dart` in the preCommit hook of `melos version`.
- `CHANGELOG.md` (root, the workspace changelog) and `packages/*/CHANGELOG.md`: written by `melos version` from commit messages at release time.
- `packages/flutterfire_cli/test/goldens/firebase_options_just_web.dart_`: the exact `firebase_options.dart` that `firebase_dart_configuration_write_test.dart` expects for a web-only config. The `.dart_` extension keeps it away from the analyzer and the formatter. Update it only when you change the generated output on purpose.

## Conventions

- PR titles follow Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `ci:`); `.github/workflows/pr_title.yaml` enforces this. Commit messages feed the changelogs and version bumps.
- One PR per fix or feature. Bug fixes include a regression test (`CONTRIBUTING.md`), preferably an offline one.
- Lints: `analysis_options.yaml` turns on every rule in `all_lint_rules.yaml` except a few, and CI fails on infos. Expect single quotes, `final` locals, trailing commas and relative imports inside `lib/`.
- The root `README.md` documents the commands and flags for users, so describe every new flag or behavior there. `packages/flutterfire_cli/README.md` is only the short pub.dev page.
- For errors meant for users, throw a `FlutterFireException` subclass from `common/strings.dart`. `bin/flutterfire.dart` prints it to stderr and exits 1.

## Gotchas

- `platform` is capped below 3.2.0 in `packages/flutterfire_cli/pubspec.yaml` on purpose: 3.2.0 deprecates `LocalPlatform`, and its replacement needs Dart ^3.10. Lifting the cap means raising the SDK constraint (`^3.6.0`).
- Windows is supported:
  - Start `flutter` and `firebase` with `runInShell: true`; they are `.bat` files there (dart-lang/sdk#31291).
  - Build paths with `package:path`. For paths written into files, use `relativePath` / `replaceBackslash` from `common/utils.dart`.
- Apple steps run only on macOS. They edit the Xcode project through generated Ruby scripts that use the `xcodeproj` gem; escape interpolated values with `escapeRubySingleQuoted`.
- Edits to user files must be idempotent: running `configure` again must not duplicate blocks. Gradle blocks sit between `// START: FlutterFire Configuration` and `// END: FlutterFire Configuration` markers.
- Prompts use the `interact` package and need a terminal. CI is detected with the `ci` package (`isCI`). To run the CLI without prompts, pass flags (`--yes`, `--project`, `--platforms`, app IDs).
