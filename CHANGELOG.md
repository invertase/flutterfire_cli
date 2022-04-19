# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2022-04-19

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`flutterfire_cli` - `v0.2.1`](#flutterfire_cli---v021)

---

#### `flutterfire_cli` - `v0.2.1`

 - **FEAT**: add support to auto apply Crashlytics & Performance Android Gradle plugins (#60). ([e620723a](https://github.com/invertase/flutterfire_cli/commit/e620723ac1e6badeb7c100a028ff2e698078f5f6))
 - **FEAT**: add hidden flag to allow opting out of app id json file generation. ([5de692c0](https://github.com/invertase/flutterfire_cli/commit/5de692c048c655b92843417dafcd85c4e1461b36))


## 2022-04-13

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`flutterfire_cli` - `v0.2.0`](#flutterfire_cli---v020)

---

#### `flutterfire_cli` - `v0.2.0`

 - **REFACTOR**: deprecate `android-application-id` in favour of `android-package-name` (#52). ([a6d398b5](https://github.com/invertase/flutterfire_cli/commit/a6d398b5bf15cfb0be30bc30682804f7041ed9e7))
 - **REFACTOR**: change messaging of already exists. ([c5ea85e1](https://github.com/invertase/flutterfire_cli/commit/c5ea85e1074a1acf8152a932bf9c74e6a84f6c85))
 - **FIX**: move autoupdater log inside conditional (#57). ([0650e181](https://github.com/invertase/flutterfire_cli/commit/0650e18178598a5496a1b17705e958e765ff2ee1))
 - **FEAT**: support auto integration of the Android Google Services plugin (#58). ([843d695a](https://github.com/invertase/flutterfire_cli/commit/843d695a71049a17d9f9d2e1d1b6885b2835497e))


## 2022-03-30

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`flutterfire_cli` - `v0.1.3`](#flutterfire_cli---v013)

---

#### `flutterfire_cli` - `v0.1.3`

 - **FEAT**: add messaging sender id to output. ([3ba34aed](https://github.com/invertase/flutterfire_cli/commit/3ba34aed8c6565ff2c471b1f519fe33401016a65))


## 2022-03-30

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`flutterfire_cli` - `v0.1.2`](#flutterfire_cli---v012)

---

#### `flutterfire_cli` - `v0.1.2`

 - **REFACTOR**: use separate `ci` package for CI environment detection. ([d9921433](https://github.com/invertase/flutterfire_cli/commit/d99214334ebfd45d18ae8046dad1f89936dd7bf0))
 - **FIX**: update `pubspec` dependency version to fix #32. ([ccd0655d](https://github.com/invertase/flutterfire_cli/commit/ccd0655df8548a062ec011f0352d57a99f771f17))
 - **FIX**: flutter app detection issues when using `flutter_localizations` (fixes #37 & #45). ([04d4e6c7](https://github.com/invertase/flutterfire_cli/commit/04d4e6c702ee08730fcfed8e05e4850a5e79bea7))
 - **FIX**: ignore `avoid_classes_with_only_static_members` in the generated options file (#42). ([6c27ae17](https://github.com/invertase/flutterfire_cli/commit/6c27ae17aaf4a91b4cefd712179e0b8686c30357))
 - **FEAT**: add `--yes` flag to automatically accept default options on prompts (closes #48). ([657892c8](https://github.com/invertase/flutterfire_cli/commit/657892c873178961209bf77c1120e032f77221d6))
 - **FEAT**: prompt to update CLI if version is older than latest published version. ([a88ade11](https://github.com/invertase/flutterfire_cli/commit/a88ade11a96c88b209c52a8dd1d2867afecd4a7d))
 - **FEAT**: updates configure to also write out Android app ID files (#51). ([991d5a43](https://github.com/invertase/flutterfire_cli/commit/991d5a433b31c2b45dcccc7ee6eea458d2bb5c7b))
 - **FEAT**: updates `configure` to also write out iOS app ID files (#43). ([e7d5a8fe](https://github.com/invertase/flutterfire_cli/commit/e7d5a8fef81f003ef8b49cb3d8cea3fec98175bb))


## 2021-12-10

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`flutterfire_cli` - `v0.1.1+2`](#flutterfire_cli---v0112)

---

#### `flutterfire_cli` - `v0.1.1+2`

 - **FIX**: don't globally require a Flutter app, this allows for help commands to work (fixes #7).
 - **FIX**: don't use `lib/main.dart` as a way of detecting a flutter app, `isFlutterPackage` & `!isFlutterPlugin` should suffice (fixes #12).


## 2021-12-03

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`flutterfire_cli` - `v0.1.0+3`](#flutterfire_cli---v0103)

---

#### `flutterfire_cli` - `v0.1.0+3`

 - **FIX**: potentially fix a crash when selecting Firebase projects.


## 2021-12-02

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`flutterfire_cli` - `v0.1.0+2`](#flutterfire_cli---v0102)

---

#### `flutterfire_cli` - `v0.1.0+2`

 - **FIX**: bug with prompt messages and FirebaseApp.displayName can be null.


## 2021-12-02

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`flutterfire_cli` - `v0.1.0+1`](#flutterfire_cli---v0101)

---

#### `flutterfire_cli` - `v0.1.0+1`

 - **FIX**: `-v` should also print the current version.

