## 0.3.0-dev.16

 - **FIX**: update json after 2nd run of `flutterfire configure`. ([bb285236](https://github.com/invertase/flutterfire_cli/commit/bb285236e4e3622fddfa5cbccdebd17e7af82c51))

## 0.3.0-dev.15

 - **REFACTOR**: allow macOS configuration for scripts. ([7384bd9f](https://github.com/invertase/flutterfire_cli/commit/7384bd9f89c00326a1aedf71c02151fd856416f3))
 - **REFACTOR**: remove dead code and move other to apple file. ([781fad2d](https://github.com/invertase/flutterfire_cli/commit/781fad2d4da4a49bdb408026eb696447df3729c5))
 - **REFACTOR**: use build configuration & call FF bundle-service-file. ([4836124a](https://github.com/invertase/flutterfire_cli/commit/4836124ae180d57be0f47d38fcbbfaf1ad440524))
 - **REFACTOR**: make functions out of reusable code. ([86e82d72](https://github.com/invertase/flutterfire_cli/commit/86e82d72d96cdb05734aabacaefd51c5731e5e68))
 - **REFACTOR**: remove unnecessary code. ([38c62ee9](https://github.com/invertase/flutterfire_cli/commit/38c62ee96529f39e7fea30057544e7e95b14e4f2))
 - **REFACTOR**: big refactor to clean up code. ([f8c42643](https://github.com/invertase/flutterfire_cli/commit/f8c426434f1b5f618d093c1a8bdd5e40edb2b833))
 - **REFACTOR**: cleaned up code. ([99a92de1](https://github.com/invertase/flutterfire_cli/commit/99a92de1ce96e8a780234eadfaa2d4a707baaced))
 - **FIX**: stop `default/default` path to default app_id_file in .dart_tools. ([24730e15](https://github.com/invertase/flutterfire_cli/commit/24730e154dd4beda9850ce27ecb7ba1a9cc57efe))
 - **FIX**: default config so it writes to default map & default/ app id file. ([9542cc69](https://github.com/invertase/flutterfire_cli/commit/9542cc694dd4a83ea9c27a4df234885f67cd5ee2))
 - **FIX**: conditions for writing service file. ([4113cdb8](https://github.com/invertase/flutterfire_cli/commit/4113cdb850f943ea1e5810d075318366f6f20bb8))
 - **FIX**: output should be relative to project. ([5f9f824c](https://github.com/invertase/flutterfire_cli/commit/5f9f824c487a273240505b4455587b0b2a74e116))
 - **FIX**: bug writing firebase.json. ([2f4f3dc4](https://github.com/invertase/flutterfire_cli/commit/2f4f3dc4af9e5d45849c7edf48473aec4d9c3676))
 - **FIX**: update scheme. ([25a8cb23](https://github.com/invertase/flutterfire_cli/commit/25a8cb23e36ed617ed4a6c1be5a3cdb150af32f4))
 - **FIX**: add filename to path. ([962eb2af](https://github.com/invertase/flutterfire_cli/commit/962eb2af5904db4c7d1d6edae5975fe767ea79a8))
 - **FIX**: add paths to debug script to find executables. ([6e7495b6](https://github.com/invertase/flutterfire_cli/commit/6e7495b6b32f398559294aa0b39fe51af7c63513))
 - **FIX**: use iOS path as FlutterApp is not available when running from xcode. ([8074f966](https://github.com/invertase/flutterfire_cli/commit/8074f96670dd83553c9f51fb217b6ed8984b66d7))
 - **FEAT**: create serviceFileOutput property on firebase.json. ([6f16b972](https://github.com/invertase/flutterfire_cli/commit/6f16b9722948bf8fee5dee7525306c207990c472))
 - **FEAT**: upload debug symbols script. ([b7512b46](https://github.com/invertase/flutterfire_cli/commit/b7512b465a6563dd86ef5e5fc9dd869f002485c1))

## 0.3.0-dev.14

 - **FEAT**: command line arguments for different environments. ([02cf8501](https://github.com/invertase/flutterfire_cli/commit/02cf8501f1c6303ed99aa888e1b2698c43481a0e))

## 0.3.0-dev.13

 - **FEAT**: new command line args for service file output. ([c335a26b](https://github.com/invertase/flutterfire_cli/commit/c335a26bf7748ab218ecd846b8f22ea96433cbdb))

## 0.2.7

 - **FEAT**: remove package the user should not depend on. ([9faa9e13](https://github.com/invertase/flutterfire_cli/commit/9faa9e13ed73673f9c46262fb2a5b2622ce684fd))
 - **FEAT**: add a flutterfire update command. ([0257d4d9](https://github.com/invertase/flutterfire_cli/commit/0257d4d96401cf3dee21c1da4a5a7c5831bdcd4e))
 - **FEAT**: Allow selecting web app id. ([413e61b7](https://github.com/invertase/flutterfire_cli/commit/413e61b7aa5fa93f6c12d202e26390f8f2fa67f5))

## 0.2.6+1

 - **FIX**: add GoogleService-Info.plist as bundle resource not compile source. ([e5561e04](https://github.com/invertase/flutterfire_cli/commit/e5561e04374f4c6d0a2076bed5a3f91378382b16))

## 0.2.6

- **FIX**: GoogleService-Info.plist file not found by Firebase SDK unless added to target ([b7b307b](https://github.com/invertase/flutterfire_cli/commit/b7b307b78af35d5313eea1dab29cf25864bd6955))
- **REFACTOR**: remove deprecated templating ([c5e34f1](https://github.com/invertase/flutterfire_cli/commit/c5e34f1b6c546bd58a58a060a10bad5b6c7b2149))
- **FIX**: reuse projectId when displayName is null on configure ([5919d4e](https://github.com/invertase/flutterfire_cli/commit/5919d4ee85033e97948021637e027a50a4c3f297))

## 0.2.5

- **FIX**: throw exception if target is not called Runner. ([64ad3318](https://github.com/invertase/flutterfire_cli/commit/64ad3318f86061e560035b18a280164c0377e952))
- **FIX**: file not found by firebase unless added to target. ([74a6fdac](https://github.com/invertase/flutterfire_cli/commit/74a6fdaccaa11f9b9f1cb31e34d9b04c149b36eb))
- **FEAT**: add mason template. ([958e92c5](https://github.com/invertase/flutterfire_cli/commit/958e92c5f134af838c236fd4980d922ff966ef6e))

## 0.2.4

- **CHORE**: Release `flutterfire_cli` again due to incorrect versioning for `0.2.3` release.

## 0.2.3

- **FIX**: switch to inline ruby script. ([3dab9b2f](https://github.com/invertase/flutterfire_cli/commit/3dab9b2fbbfdc0b9225224a625b8f89074d5ea3f))
- **FIX**: path to ruby script. ([eb0427e6](https://github.com/invertase/flutterfire_cli/commit/eb0427e604c1bf7fe46bf15c387077a077f22571))
- **FIX**: use "resolvePackageUri" to get package. ([e72a2a54](https://github.com/invertase/flutterfire_cli/commit/e72a2a549e197594e1d659164819e289f88bb317))
- **FIX**: add missing `account` argument specification for create\*App. ([4987250a](https://github.com/invertase/flutterfire_cli/commit/4987250a197dfb4731f625e988f3059e3e550b1e))
- **FEAT**: update macOS with google services file & pbxproj file. ([b5ca92ce](https://github.com/invertase/flutterfire_cli/commit/b5ca92ced93de46a9d029f9272a5c9ace2793516))
- **FEAT**: only update config and write plist file if they don't exist. ([ccfa3510](https://github.com/invertase/flutterfire_cli/commit/ccfa3510f7b4fae135a1e041c1774bd9717fc131))
- **FEAT**: add GoogleServices file and update pbxproj file. ([1a3e945a](https://github.com/invertase/flutterfire_cli/commit/1a3e945a3e3ab3501bef32bbc930d72af61df820))

## 0.2.2+2

- **FIX**: null issue with Windows & Linux platform selectors (fixes [#76](https://github.com/invertase/flutterfire_cli/issues/76)). ([9c2a2dc5](https://github.com/invertase/flutterfire_cli/commit/9c2a2dc5b9fc95f4051da06832d5e5e917906449))

## 0.2.2+1

- **FIX**: create output file directory if it does not exist (fixes [#75](https://github.com/invertase/flutterfire_cli/issues/75)). ([fe1370c3](https://github.com/invertase/flutterfire_cli/commit/fe1370c3259884cbd2a1a103626b375b420d621a))
- **FIX**: only show Windows/Linux options if desktop packages are installed in Flutter app. ([2da944c4](https://github.com/invertase/flutterfire_cli/commit/2da944c45b0c9e1308eecb8ea1ff21295eabeafa))

## 0.2.2

- **REFACTOR**: move strings to own file for easier review ([#61](https://github.com/invertase/flutterfire_cli/issues/61)). ([723f9797](https://github.com/invertase/flutterfire_cli/commit/723f9797c41db4a008804116a1cb0ea069aaa238))
- **FEAT**: add new `--platforms` flag to specify platforms to generate Firebase options for without prompts (Closes [#68](https://github.com/invertase/flutterfire_cli/issues/68)) ([#72](https://github.com/invertase/flutterfire_cli/issues/72)). ([e7b309e6](https://github.com/invertase/flutterfire_cli/commit/e7b309e682eabd0d7f048e3b30e4ee84ab4995e4))
- **FEAT**: add support for Windows & Linux platforms via Firebase Web apps. ([#71](https://github.com/invertase/flutterfire_cli/issues/71)). ([ed3b8f2c](https://github.com/invertase/flutterfire_cli/commit/ed3b8f2c1f6ee4617742320856837b42f26cce05))
- **DOCS**: remove broken link. ([acd07c85](https://github.com/invertase/flutterfire_cli/commit/acd07c85647d970a44bf5b6d29593f87c99ce8e7))

## 0.2.1+1

- **FIX**: use correct platform name when detecting ios bundle ids. ([135a1050](https://github.com/invertase/flutterfire_cli/commit/135a1050f0f1a65125aae308411149032c83391e))

## 0.2.1

- **FEAT**: add support to auto apply Crashlytics & Performance Android Gradle plugins (#60). ([e620723a](https://github.com/invertase/flutterfire_cli/commit/e620723ac1e6badeb7c100a028ff2e698078f5f6))
- **FEAT**: add hidden flag to allow opting out of app id json file generation. ([5de692c0](https://github.com/invertase/flutterfire_cli/commit/5de692c048c655b92843417dafcd85c4e1461b36))

## 0.2.0

- **REFACTOR**: deprecate `android-application-id` in favour of `android-package-name` (#52). ([a6d398b5](https://github.com/invertase/flutterfire_cli/commit/a6d398b5bf15cfb0be30bc30682804f7041ed9e7))
- **REFACTOR**: change messaging of already exists. ([c5ea85e1](https://github.com/invertase/flutterfire_cli/commit/c5ea85e1074a1acf8152a932bf9c74e6a84f6c85))
- **FIX**: move autoupdater log inside conditional (#57). ([0650e181](https://github.com/invertase/flutterfire_cli/commit/0650e18178598a5496a1b17705e958e765ff2ee1))
- **FEAT**: support auto integration of the Android Google Services plugin (#58). ([843d695a](https://github.com/invertase/flutterfire_cli/commit/843d695a71049a17d9f9d2e1d1b6885b2835497e))

## 0.1.3

- **FEAT**: add messaging sender id to output. ([3ba34aed](https://github.com/invertase/flutterfire_cli/commit/3ba34aed8c6565ff2c471b1f519fe33401016a65))

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
