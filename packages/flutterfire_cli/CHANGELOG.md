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
