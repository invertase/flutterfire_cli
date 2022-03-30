## 0.1.2

 - **REFACTOR**: use separate `ci` package for CI environment detection. ([d9921433](https://github.com/invertase/flutterfire_cli/commit/d99214334ebfd45d18ae8046dad1f89936dd7bf0))
 - **FIX**: update `pubspec` dependency version to fix #32. ([ccd0655d](https://github.com/invertase/flutterfire_cli/commit/ccd0655df8548a062ec011f0352d57a99f771f17))
 - **FIX**: flutter app detection issues when using `flutter_localizations` (fixes #37 & #45). ([04d4e6c7](https://github.com/invertase/flutterfire_cli/commit/04d4e6c702ee08730fcfed8e05e4850a5e79bea7))
 - **FIX**: ignore `avoid_classes_with_only_static_members` in the generated options file (#42). ([6c27ae17](https://github.com/invertase/flutterfire_cli/commit/6c27ae17aaf4a91b4cefd712179e0b8686c30357))
 - **FEAT**: add `--yes` flag to automatically accept default options on prompts (closes #48). ([657892c8](https://github.com/invertase/flutterfire_cli/commit/657892c873178961209bf77c1120e032f77221d6))
 - **FEAT**: prompt to update CLI if version is older than latest published version. ([a88ade11](https://github.com/invertase/flutterfire_cli/commit/a88ade11a96c88b209c52a8dd1d2867afecd4a7d))
 - **FEAT**: updates configure to also write out Android app ID files (#51). ([991d5a43](https://github.com/invertase/flutterfire_cli/commit/991d5a433b31c2b45dcccc7ee6eea458d2bb5c7b))
 - **FEAT**: updates `configure` to also write out iOS app ID files (#43). ([e7d5a8fe](https://github.com/invertase/flutterfire_cli/commit/e7d5a8fef81f003ef8b49cb3d8cea3fec98175bb))

## 0.1.1+2

 - **FIX**: don't globally require a Flutter app, this allows for help commands to work (fixes #7). ([94aa8d64](https://github.com/invertase/flutterfire_cli/commit/94aa8d64c467e1cec31e7bbc6c06acb247bc92bc))
 - **FIX**: don't use `lib/main.dart` as a way of detecting a flutter app, `isFlutterPackage` & `!isFlutterPlugin` should suffice (fixes #12). ([b4df767d](https://github.com/invertase/flutterfire_cli/commit/b4df767d2328567dc5461b068bbe9f2872d43636))

## 0.1.1+1

 - **FIX**: add `lines_longer_than_80_chars` ignore for file lint rule in generated options file.

## 0.1.1

 - **FIX**: run all firebase cli commands in shell - avoids unhelpful process not found exception messages.
 - **FIX**: late initialisation error (only on happens on Windows).
 - **FIX**: Add `runInShell` when running on Windows (#4).
 - **FEAT**: additionally support reading apple bundle identifier from `AppInfo.xcconfig`.

## 0.1.0+4

 - **FIX**: late initialisation error (only on happens on Windows).
 - **FIX**: Add `runInShell` when running on Windows (#4).
 - **FIX**: potentially fix a crash when selecting Firebase projects.

## 0.1.0+3

 - **FIX**: potentially fix a crash when selecting Firebase projects.

## 0.1.0+2

 - **FIX**: bug with prompt messages and FirebaseApp.displayName can be null.

## 0.1.0+1

 - **FIX**: `-v` should also print the current version.

## 0.1.0

- Initial version.
