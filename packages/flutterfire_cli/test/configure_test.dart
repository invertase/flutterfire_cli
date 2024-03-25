import 'dart:convert';
import 'dart:io';

import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:flutterfire_cli/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'reconfigure_test.dart';
import 'test_utils.dart';

void main() {
  String? projectPath;
  setUp(() async {
    projectPath = await createFlutterProject();
  });

  tearDown(() {
    Directory(p.dirname(projectPath!)).delete(recursive: true);
  });

  test(
    'flutterfire configure: android - "default" Apple - "default"',
    () async {
      // the most basic 'flutterfire configure' command that can be run without command line prompts
      const defaultTarget = 'Runner';
      final result = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--platforms=android,ios,macos,web,windows',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
          '--windows-app-id=$windowsAppId',
          '--project=$firebaseProjectId',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      if (Platform.isMacOS) {
        // check Apple service files were created and have correct content
        final iosPath =
            p.join(projectPath!, kIos, defaultTarget, appleServiceFileName);
        final macosPath = p.join(projectPath!, kMacos, defaultTarget);

        await testAppleServiceFileValues(iosPath);
        await testAppleServiceFileValues(
          macosPath,
          platform: kMacos,
        );

        // check default "firebase.json" was created and has correct content
        final firebaseJsonFile = p.join(projectPath!, 'firebase.json');
        final firebaseJsonFileContent =
            await File(firebaseJsonFile).readAsString();

        final decodedFirebaseJson =
            jsonDecode(firebaseJsonFileContent) as Map<String, dynamic>;

        checkAppleFirebaseJsonValues(
          decodedFirebaseJson,
          [kFlutter, kPlatforms, kIos, kDefaultConfig],
          '$kIos/$defaultTarget/$appleServiceFileName',
        );
        checkAppleFirebaseJsonValues(
          decodedFirebaseJson,
          [
            kFlutter,
            kPlatforms,
            kMacos,
            kDefaultConfig,
          ],
          '$kMacos/$defaultTarget/$appleServiceFileName',
        );

        checkAndroidFirebaseJsonValues(
          decodedFirebaseJson,
          [
            kFlutter,
            kPlatforms,
            kAndroid,
            kDefaultConfig,
          ],
          'android/app/$androidServiceFileName',
        );

        const defaultFilePath = 'lib/firebase_options.dart';
        final keysToMapDart = [kFlutter, kPlatforms, kDart, defaultFilePath];

        checkDartFirebaseJsonValues(
          decodedFirebaseJson,
          keysToMapDart,
        );

        // check GoogleService-Info.plist file is included & debug symbols script (until firebase crashlytics is a dependency) is not included in Apple "project.pbxproj" files
        final iosXcodeProject = p.join(
          projectPath!,
          kIos,
          'Runner.xcodeproj',
        );

        final scriptToCheckIosPbxprojFile =
            rubyScriptForTestingDefaultConfigure(iosXcodeProject);

        final iosResult = Process.runSync(
          'ruby',
          [
            '-e',
            scriptToCheckIosPbxprojFile,
          ],
          runInShell: true,
        );

        if (iosResult.exitCode != 0) {
          fail(iosResult.stderr as String);
        }

        expect(iosResult.stdout, 'success');

        final macosXcodeProject = p.join(
          projectPath!,
          kMacos,
          'Runner.xcodeproj',
        );

        final scriptToCheckMacosPbxprojFile =
            rubyScriptForTestingDefaultConfigure(
          macosXcodeProject,
        );

        final macosResult = Process.runSync(
          'ruby',
          [
            '-e',
            scriptToCheckMacosPbxprojFile,
          ],
          runInShell: true,
        );

        if (macosResult.exitCode != 0) {
          fail(macosResult.stderr as String);
        }

        expect(macosResult.stdout, 'success');
      }

      // check google-services.json was created and has correct content
      final androidServiceFilePath = p.join(
        projectPath!,
        'android',
        'app',
        androidServiceFileName,
      );
      testAndroidServiceFileValues(androidServiceFilePath);

      // Check android "android/settings.gradle" & "android/app/build.gradle" were updated
      await checkBuildGradleFileUpdated(projectPath!);

      // check "firebase_options.dart" file is created in lib directory
      final firebaseOptions =
          p.join(projectPath!, 'lib', 'firebase_options.dart');

      await testFirebaseOptionsFileValues(firebaseOptions);
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

  test(
    'flutterfire configure: android - "build configuration" Apple - "build configuration"',
    () async {
      final result = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--platforms=android,ios,macos,web,windows',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
          '--windows-app-id=$windowsAppId',
          // Android just requires the `--android-out` flag to be set
          '--android-out=android/app/$buildType',
          // Apple required the `--ios-out` and `--macos-out` flags to be set & the build type,
          // We're using `Debug` for both which is a standard build configuration for an apple Flutter app
          '--ios-out=ios/$buildType',
          '--ios-build-config=$appleBuildConfiguration',
          '--macos-out=macos/$buildType',
          '--macos-build-config=$appleBuildConfiguration',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      if (Platform.isMacOS) {
        // check Apple service files were created and have correct content
        final iosPath = p.join(
          projectPath!,
          kIos,
          buildType,
          appleServiceFileName,
        );
        final macosPath = p.join(
          projectPath!,
          kMacos,
          buildType,
        );

        await testAppleServiceFileValues(iosPath);
        await testAppleServiceFileValues(
          macosPath,
          platform: kMacos,
        );

        // check default "firebase.json" was created and has correct content
        final firebaseJsonFile = p.join(projectPath!, 'firebase.json');
        final firebaseJsonFileContent =
            await File(firebaseJsonFile).readAsString();

        final decodedFirebaseJson =
            jsonDecode(firebaseJsonFileContent) as Map<String, dynamic>;

        checkAppleFirebaseJsonValues(
          decodedFirebaseJson,
          [
            kFlutter,
            kPlatforms,
            kIos,
            kBuildConfiguration,
            appleBuildConfiguration,
          ],
          'ios/$buildType/GoogleService-Info.plist',
        );

        checkAppleFirebaseJsonValues(
          decodedFirebaseJson,
          [
            kFlutter,
            kPlatforms,
            kMacos,
            kBuildConfiguration,
            appleBuildConfiguration,
          ],
          'macos/$buildType/GoogleService-Info.plist',
        );

        checkAndroidFirebaseJsonValues(
          decodedFirebaseJson,
          [
            kFlutter,
            kPlatforms,
            kAndroid,
            kBuildConfiguration,
            buildType,
          ],
          'android/app/$buildType/google-services.json',
        );

        const defaultFilePath = 'lib/firebase_options.dart';
        final keysToMapDart = [kFlutter, kPlatforms, kDart, defaultFilePath];
        checkDartFirebaseJsonValues(
          decodedFirebaseJson,
          keysToMapDart,
        );

        final scriptToCheckIosPbxprojFile =
            rubyScriptForCheckingBundleResourcesScript(
          projectPath!,
          kIos,
        );

        final iosResult = Process.runSync(
          'ruby',
          [
            '-e',
            scriptToCheckIosPbxprojFile,
          ],
          runInShell: true,
        );

        if (iosResult.exitCode != 0) {
          fail(iosResult.stderr as String);
        }

        expect(iosResult.stdout, 'success');

        final scriptToCheckMacosPbxprojFile =
            rubyScriptForCheckingBundleResourcesScript(
          projectPath!,
          kMacos,
        );

        final macosResult = Process.runSync(
          'ruby',
          [
            '-e',
            scriptToCheckMacosPbxprojFile,
          ],
          runInShell: true,
        );

        if (macosResult.exitCode != 0) {
          fail(macosResult.stderr as String);
        }

        expect(macosResult.stdout, 'success');
      }

      // check google-services.json was created and has correct content
      final androidServiceFilePath = p.join(
        projectPath!,
        'android',
        'app',
        buildType,
        'google-services.json',
      );
      testAndroidServiceFileValues(androidServiceFilePath);

      // Check android "android/settings.gradle" & "android/app/build.gradle" were updated
      await checkBuildGradleFileUpdated(projectPath!);

      // check "firebase_options.dart" file is created in lib directory
      final firebaseOptions =
          p.join(projectPath!, 'lib', 'firebase_options.dart');

      await testFirebaseOptionsFileValues(firebaseOptions);
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

  test(
    'flutterfire configure: android - "default" Apple - "target"',
    () async {
      const targetType = 'Runner';
      const applePath = 'staging/target';
      const androidBuildConfiguration = 'development';
      final result = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--platforms=android,ios,macos,web,windows',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
          '--windows-app-id=$windowsAppId',
          // Android just requires the `--android-out` flag to be set
          '--android-out=android/app/$androidBuildConfiguration',
          // Apple required the `--ios-out` and `--macos-out` flags to be set & the build type,
          // We're using `Runner` target for both which is the standard target for an apple Flutter app
          '--ios-out=ios/$applePath',
          '--ios-target=$targetType',
          '--macos-out=macos/$applePath',
          '--macos-target=$targetType',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      if (Platform.isMacOS) {
        // check Apple service files were created and have correct content
        final iosPath =
            p.join(projectPath!, kIos, applePath, appleServiceFileName);
        final macosPath = p.join(projectPath!, kMacos, applePath);

        await testAppleServiceFileValues(iosPath);
        await testAppleServiceFileValues(
          macosPath,
          platform: kMacos,
        );

        // check default "firebase.json" was created and has correct content
        final firebaseJsonFile = p.join(projectPath!, 'firebase.json');
        final firebaseJsonFileContent =
            await File(firebaseJsonFile).readAsString();

        final decodedFirebaseJson =
            jsonDecode(firebaseJsonFileContent) as Map<String, dynamic>;

        checkAppleFirebaseJsonValues(
          decodedFirebaseJson,
          [
            kFlutter,
            kPlatforms,
            kIos,
            kTargets,
            targetType,
          ],
          'ios/$applePath/GoogleService-Info.plist',
        );

        checkAppleFirebaseJsonValues(
          decodedFirebaseJson,
          [kFlutter, kPlatforms, kMacos, kTargets, targetType],
          'macos/$applePath/GoogleService-Info.plist',
        );

        checkAndroidFirebaseJsonValues(
          decodedFirebaseJson,
          [
            kFlutter,
            kPlatforms,
            kAndroid,
            kBuildConfiguration,
            androidBuildConfiguration,
          ],
          'android/app/$androidBuildConfiguration/google-services.json',
        );

        // Check dart map is correct
        const defaultFilePath = 'lib/firebase_options.dart';
        final keysToMapDart = [kFlutter, kPlatforms, kDart, defaultFilePath];
        checkDartFirebaseJsonValues(decodedFirebaseJson, keysToMapDart);

        // check GoogleService-Info.plist file is included & debug symbols script (until firebase crashlytics is a dependency) is not included in Apple "project.pbxproj" files
        final iosXcodeProject = p.join(
          projectPath!,
          kIos,
          'Runner.xcodeproj',
        );

        final scriptToCheckIosPbxprojFile =
            rubyScriptForTestingDefaultConfigure(iosXcodeProject);

        final iosResult = Process.runSync(
          'ruby',
          [
            '-e',
            scriptToCheckIosPbxprojFile,
          ],
          runInShell: true,
        );

        if (iosResult.exitCode != 0) {
          fail(iosResult.stderr as String);
        }

        expect(iosResult.stdout, 'success');

        final macosXcodeProject = p.join(
          projectPath!,
          kMacos,
          'Runner.xcodeproj',
        );

        final scriptToCheckMacosPbxprojFile =
            rubyScriptForTestingDefaultConfigure(
          macosXcodeProject,
        );

        final macosResult = Process.runSync(
          'ruby',
          [
            '-e',
            scriptToCheckMacosPbxprojFile,
          ],
          runInShell: true,
        );

        if (macosResult.exitCode != 0) {
          fail(macosResult.stderr as String);
        }

        expect(macosResult.stdout, 'success');
      }

      // check google-services.json was created and has correct content
      final androidServiceFilePath = p.join(
        projectPath!,
        'android',
        'app',
        androidBuildConfiguration,
        'google-services.json',
      );
      testAndroidServiceFileValues(androidServiceFilePath);

      // Check android "android/settings.gradle" & "android/app/build.gradle" were updated
      await checkBuildGradleFileUpdated(projectPath!);

      // check "firebase_options.dart" file is created in lib directory
      final firebaseOptions =
          p.join(projectPath!, 'lib', 'firebase_options.dart');

      await testFirebaseOptionsFileValues(firebaseOptions);
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

  test(
    'Validate `flutterfire upload-crashlytics-symbols` script is included when `firebase_crashlytics` is a dependency',
    () {
      final result = Process.runSync(
        'flutter',
        ['pub', 'add', 'firebase_crashlytics'],
        workingDirectory: projectPath,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      final result2 = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--platforms=android,ios,macos,web,windows',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
          '--windows-app-id=$windowsAppId',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result2.exitCode != 0) {
        fail(result2.stderr as String);
      }

      final iosXcodeProject = p.join(
        projectPath!,
        kIos,
        'Runner.xcodeproj',
      );

      final scriptToCheckIosPbxprojFile =
          rubyScriptForTestingDebugSymbolScriptExists(iosXcodeProject);

      final iosResult = Process.runSync(
        'ruby',
        [
          '-e',
          scriptToCheckIosPbxprojFile,
        ],
        runInShell: true,
      );

      if (iosResult.exitCode != 0) {
        fail(iosResult.stderr as String);
      }

      expect(iosResult.stdout, 'success');

      final macosXcodeProject = p.join(
        projectPath!,
        kMacos,
        'Runner.xcodeproj',
      );

      final scriptToCheckMacosPbxprojFile =
          rubyScriptForTestingDebugSymbolScriptExists(
        macosXcodeProject,
      );

      final macosResult = Process.runSync(
        'ruby',
        [
          '-e',
          scriptToCheckMacosPbxprojFile,
        ],
        runInShell: true,
      );

      if (macosResult.exitCode != 0) {
        fail(macosResult.stderr as String);
      }

      expect(macosResult.stdout, 'success');
    },
    skip: !Platform.isMacOS,
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

  test(
    'flutterfire configure: rewrite service files when rerunning "flutterfire configure" with different apps',
    () async {
      const defaultTarget = 'Runner';
      // The initial configuration
      final result = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--platforms=android,ios,macos,web',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
          '--windows-app-id=$windowsAppId',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      // The second configuration with different bundle ids which we need to check
      final result2 = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--platforms=android,ios,macos,web,windows',
          '--ios-bundle-id=com.example.secondApp',
          '--android-package-name=com.example.second_app',
          '--macos-bundle-id=com.example.secondApp',
          '--web-app-id=$secondWebAppId',
          '--windows-app-id=$secondWindowsAppId',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result2.exitCode != 0) {
        fail(result2.stderr as String);
      }

      if (Platform.isMacOS) {
        // check Apple service files were created and have correct content
        final iosPath =
            p.join(projectPath!, kIos, defaultTarget, appleServiceFileName);
        final macosPath = p.join(projectPath!, kMacos, defaultTarget);

        await testAppleServiceFileValues(
          iosPath,
          appId: secondAppleAppId,
          bundleId: secondAppleBundleId,
        );
        await testAppleServiceFileValues(
          macosPath,
          platform: kMacos,
          appId: secondAppleAppId,
          bundleId: secondAppleBundleId,
        );

        // check default "firebase.json" was created and has correct content
        final firebaseJsonFile = p.join(projectPath!, 'firebase.json');
        final firebaseJsonFileContent =
            await File(firebaseJsonFile).readAsString();

        final decodedFirebaseJson =
            jsonDecode(firebaseJsonFileContent) as Map<String, dynamic>;

        checkAppleFirebaseJsonValues(
          decodedFirebaseJson,
          [kFlutter, kPlatforms, kIos, kDefaultConfig],
          '$kIos/$defaultTarget/$appleServiceFileName',
          appId: secondAppleAppId,
        );
        checkAppleFirebaseJsonValues(
          decodedFirebaseJson,
          [
            kFlutter,
            kPlatforms,
            kMacos,
            kDefaultConfig,
          ],
          '$kMacos/$defaultTarget/$appleServiceFileName',
          appId: secondAppleAppId,
        );

        checkAndroidFirebaseJsonValues(
          decodedFirebaseJson,
          [
            kFlutter,
            kPlatforms,
            kAndroid,
            kDefaultConfig,
          ],
          'android/app/$androidServiceFileName',
          appId: secondAndroidAppId,
        );

        const defaultFilePath = 'lib/firebase_options.dart';
        final keysToMapDart = [kFlutter, kPlatforms, kDart, defaultFilePath];

        checkDartFirebaseJsonValues(
          decodedFirebaseJson,
          keysToMapDart,
          androidAppId: secondAndroidAppId,
          appleAppId: secondAppleAppId,
          webAppId: secondWebAppId,
        );

        // check GoogleService-Info.plist file is included & debug symbols script (until firebase crashlytics is a dependency) is not included in Apple "project.pbxproj" files
        final iosXcodeProject = p.join(
          projectPath!,
          kIos,
          'Runner.xcodeproj',
        );

        final scriptToCheckIosPbxprojFile =
            rubyScriptForTestingDefaultConfigure(iosXcodeProject);

        final iosResult = Process.runSync(
          'ruby',
          [
            '-e',
            scriptToCheckIosPbxprojFile,
          ],
        );

        if (iosResult.exitCode != 0) {
          fail(iosResult.stderr as String);
        }

        expect(iosResult.stdout, 'success');

        final macosXcodeProject = p.join(
          projectPath!,
          kMacos,
          'Runner.xcodeproj',
        );

        final scriptToCheckMacosPbxprojFile =
            rubyScriptForTestingDefaultConfigure(
          macosXcodeProject,
        );

        final macosResult = Process.runSync(
          'ruby',
          [
            '-e',
            scriptToCheckMacosPbxprojFile,
          ],
        );

        if (macosResult.exitCode != 0) {
          fail(macosResult.stderr as String);
        }

        expect(macosResult.stdout, 'success');
      }

      // check google-services.json was created and has correct content
      final androidServiceFilePath = p.join(
        projectPath!,
        'android',
        'app',
        androidServiceFileName,
      );
      testAndroidServiceFileValues(
        androidServiceFilePath,
        appId: secondAndroidAppId,
      );

      // check "firebase_options.dart" file is created in lib directory
      final firebaseOptions =
          p.join(projectPath!, 'lib', 'firebase_options.dart');

      final firebaseOptionsContent = await File(firebaseOptions).readAsString();

      expect(
        firebaseOptionsContent.split('\n'),
        containsAll(<Matcher>[
          contains(secondAppleAppId),
          contains(secondAppleBundleId),
          contains(secondAndroidAppId),
          contains(secondWebAppId),
          contains(secondWindowsAppId),
          contains('static const FirebaseOptions web = FirebaseOptions'),
          contains('static const FirebaseOptions android = FirebaseOptions'),
          contains('static const FirebaseOptions ios = FirebaseOptions'),
          contains('static const FirebaseOptions macos = FirebaseOptions'),
          contains('static const FirebaseOptions windows = FirebaseOptions'),
        ]),
      );
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

  test(
    'flutterfire configure: test when only two platforms are selected, not including "web" platform',
    () async {
      const defaultTarget = 'Runner';

      final result = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--platforms=ios,android',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
          '--windows-app-id=$windowsAppId',
          '--project=$firebaseProjectId',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      if (Platform.isMacOS) {
        // check iOS service files were created and have correct content
        final iosPath =
            p.join(projectPath!, kIos, defaultTarget, appleServiceFileName);

        await testAppleServiceFileValues(
          iosPath,
        );

        // check default "firebase.json" was created and has correct content
        final firebaseJsonFile = p.join(projectPath!, 'firebase.json');
        final firebaseJsonFileContent =
            await File(firebaseJsonFile).readAsString();

        final decodedFirebaseJson =
            jsonDecode(firebaseJsonFileContent) as Map<String, dynamic>;

        checkAppleFirebaseJsonValues(
          decodedFirebaseJson,
          [kFlutter, kPlatforms, kIos, kDefaultConfig],
          '$kIos/$defaultTarget/$appleServiceFileName',
        );

        checkAndroidFirebaseJsonValues(
          decodedFirebaseJson,
          [
            kFlutter,
            kPlatforms,
            kAndroid,
            kDefaultConfig,
          ],
          'android/app/$androidServiceFileName',
        );

        const defaultFilePath = 'lib/firebase_options.dart';
        final keysToMapDart = [kFlutter, kPlatforms, kDart, defaultFilePath];

        checkDartFirebaseJsonValues(
          decodedFirebaseJson,
          keysToMapDart,
          checkMacos: false,
          checkWeb: false,
        );

        // check GoogleService-Info.plist file is included & debug symbols script (until firebase crashlytics is a dependency) is not included in Apple "project.pbxproj" files
        final iosXcodeProject = p.join(
          projectPath!,
          kIos,
          'Runner.xcodeproj',
        );

        final scriptToCheckIosPbxprojFile =
            rubyScriptForTestingDefaultConfigure(iosXcodeProject);

        final iosResult = Process.runSync(
          'ruby',
          [
            '-e',
            scriptToCheckIosPbxprojFile,
          ],
        );

        if (iosResult.exitCode != 0) {
          fail(iosResult.stderr as String);
        }

        expect(iosResult.stdout, 'success');
      }

      // check google-services.json was created and has correct content
      final androidServiceFilePath = p.join(
        projectPath!,
        'android',
        'app',
        androidServiceFileName,
      );
      testAndroidServiceFileValues(
        androidServiceFilePath,
      );

      // check "firebase_options.dart" file is created in lib directory
      final firebaseOptions =
          p.join(projectPath!, 'lib', 'firebase_options.dart');

      final firebaseOptionsContent = await File(firebaseOptions).readAsString();

      final listOfStrings = firebaseOptionsContent.split('\n');
      expect(
        listOfStrings,
        containsAll(<Matcher>[
          contains(appleAppId),
          contains(appleBundleId),
          contains(androidAppId),
          contains('static const FirebaseOptions android = FirebaseOptions'),
          contains('static const FirebaseOptions ios = FirebaseOptions'),
        ]),
      );
      expect(
        firebaseOptionsContent
            .contains('static const FirebaseOptions web = FirebaseOptions'),
        isFalse,
      );
      expect(
        firebaseOptionsContent
            .contains('static const FirebaseOptions windows = FirebaseOptions'),
        isFalse,
      );
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

  test(
    'flutterfire configure: test will reconfigure project if no args and `firebase.json` is present',
    () async {
      const defaultTarget = 'Runner';
      // Set up  initial configuration
      final result = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          '--platforms=android,ios',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
          '--windows-app-id=$windowsAppId',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      // Now firebase.json file has been written, change values in service files to test they are rewritten
      if (Platform.isMacOS) {
        final iosPath =
            p.join(projectPath!, kIos, defaultTarget, appleServiceFileName);

        // Clean out file to test it was recreated
        await File(iosPath).writeAsString('');
      }

      final androidServiceFilePath = p.join(
        projectPath!,
        'android',
        'app',
        androidServiceFileName,
      );
      // Clean out file to test it was recreated
      await File(androidServiceFilePath).writeAsString('');

      final firebaseOptions =
          p.join(projectPath!, 'lib', 'firebase_options.dart');

      final accessToken = await generateAccessTokenCI();
      // Perform `flutterfire configure` without args to use `flutterfire reconfigure`.
      final result2 = Process.runSync(
        'flutterfire',
        [
          'configure',
          if (accessToken != null) '--test-access-token=$accessToken',
        ],
        workingDirectory: projectPath,
        runInShell: true,
        environment: {'TEST_ENVIRONMENT': 'true'},
      );

      if (result2.exitCode != 0) {
        fail(result2.stderr as String);
      }

      if (Platform.isMacOS) {
        // check iOS service file was recreated and has correct content
        final iosPath =
            p.join(projectPath!, kIos, defaultTarget, appleServiceFileName);

        await testAppleServiceFileValues(
          iosPath,
        );
      }

      // check google-services.json was recreated and has correct content
      testAndroidServiceFileValues(
        androidServiceFilePath,
      );

      // check "firebase_options.dart" file was recreated in lib directory
      final firebaseOptionsContent = await File(firebaseOptions).readAsString();

      final listOfStrings = firebaseOptionsContent.split('\n');
      expect(
        listOfStrings,
        containsAll(<Matcher>[
          contains(appleAppId),
          contains(appleBundleId),
          contains(androidAppId),
          contains('static const FirebaseOptions android = FirebaseOptions'),
          contains('static const FirebaseOptions ios = FirebaseOptions'),
        ]),
      );
      expect(
        firebaseOptionsContent
            .contains('static const FirebaseOptions web = FirebaseOptions'),
        isFalse,
      );
      expect(
        firebaseOptionsContent
            .contains('static const FirebaseOptions windows = FirebaseOptions'),
        isFalse,
      );
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

  test(
    'flutterfire configure: write Dart configuration file to different output',
    () async {
      const configurationFileName = 'different_firebase_options.dart';
      // Set up  initial configuration
      final result = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          '--platforms=android,ios',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--platforms=android,ios,macos,web,windows',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
          '--windows-app-id=$windowsAppId',
          // Output to different file
          '--out=lib/$configurationFileName',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      final firebaseOptions =
          p.join(projectPath!, 'lib', configurationFileName);

      // check "different_firebase_options.dart" file was recreated in lib directory
      final firebaseOptionsContent = await File(firebaseOptions).readAsString();

      final listOfStrings = firebaseOptionsContent.split('\n');
      expect(
        listOfStrings,
        containsAll(<Matcher>[
          contains(appleAppId),
          contains(appleBundleId),
          contains(androidAppId),
          contains(webAppId),
          contains(windowsAppId),
          contains('static const FirebaseOptions android = FirebaseOptions'),
          contains('static const FirebaseOptions ios = FirebaseOptions'),
          contains('static const FirebaseOptions web = FirebaseOptions'),
          contains('static const FirebaseOptions windows = FirebaseOptions'),
        ]),
      );
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

  test('flutterfire configure: incorrect `--web-app-id` should throw exception',
      () async {
    final result = Process.runSync(
      'flutterfire',
      [
        'configure',
        '--yes',
        '--project=$firebaseProjectId',
        '--platforms=web',
        '--web-app-id=a-non-existent-web-app-id',
        // The below args aren't needed unless running from CI. We need for Github actions to run command.
        '--ios-bundle-id=com.example.flutterTestCli',
        '--windows-app-id=$windowsAppId',
        '--android-package-name=com.example.flutter_test_cli',
        '--macos-bundle-id=com.example.flutterTestCli',
      ],
      workingDirectory: projectPath,
      runInShell: true,
    );

    final output = result.stderr as String;
    final expectedOutput = [
      'does not match the web app id of any existing Firebase app',
      'Exception',
    ];

    final expected = expectedOutput.every(output.contains);
    expect(result.exitCode != 0, isTrue);
    expect(
      expected,
      isTrue,
    );
  });

  test(
      'flutterfire configure: incorrect `--windows-app-id` should throw exception',
      () async {
    final result = Process.runSync(
      'flutterfire',
      [
        'configure',
        '--yes',
        '--project=$firebaseProjectId',
        '--platforms=windows',
        '--web-app-id=$webAppId',
        // The below args aren't needed unless running from CI. We need for Github actions to run command.
        '--ios-bundle-id=com.example.flutterTestCli',
        // Trigger the exception
        '--windows-app-id=a-non-existent-windows-app-id',
        '--android-package-name=com.example.flutter_test_cli',
        '--macos-bundle-id=com.example.flutterTestCli',
      ],
      workingDirectory: projectPath,
      runInShell: true,
    );

    final output = result.stderr as String;
    final expectedOutput = [
      'does not match the web app id of any existing Firebase app',
      'Exception',
    ];

    final expected = expectedOutput.every(output.contains);

    expect(result.exitCode != 0, isTrue);
    expect(
      expected,
      isTrue,
    );
  });

  test(
      'flutterfire configure: get correct Firebase App with manually created Firebase web app via `--web-app-id`',
      () async {
    final result = Process.runSync(
      'flutterfire',
      [
        'configure',
        '--yes',
        '--project=$firebaseProjectId',
        '--platforms=web',
        '--web-app-id=$secondWebAppId',
        // The below args aren't needed unless running from CI. We need for Github actions to run command.
        '--ios-bundle-id=com.example.flutterTestCli',
        '--android-package-name=com.example.flutter_test_cli',
        '--macos-bundle-id=com.example.flutterTestCli',
        '--windows-app-id=$windowsAppId',
      ],
      workingDirectory: projectPath,
      runInShell: true,
    );

    expect(result.exitCode, 0);
    // Console out put looks like this on success: "web       1:262904632156:web:cb3a00412ed430ca2f2799"
    expect(
      (result.stdout as String).contains(
        'web       $secondWebAppId',
      ),
      isTrue,
    );

    // check "firebase_options.dart" file is created in lib directory
    final firebaseOptions =
        p.join(projectPath!, 'lib', 'firebase_options.dart');

    await testFirebaseOptionsFileValues(
      firebaseOptions,
      selectedPlatform: kWeb,
    );
  });

  test(
      'flutterfire configure: get correct Firebase App with manually created Firebase web app via `--windows-app-id`',
      () async {
    final result = Process.runSync(
      'flutterfire',
      [
        'configure',
        '--yes',
        '--project=$firebaseProjectId',
        '--platforms=windows',
        '--web-app-id=$webAppId',
        // The below args aren't needed unless running from CI. We need for Github actions to run command.
        '--ios-bundle-id=com.example.flutterTestCli',
        '--android-package-name=com.example.flutter_test_cli',
        '--macos-bundle-id=com.example.flutterTestCli',
        '--windows-app-id=$secondWindowsAppId',
      ],
      workingDirectory: projectPath,
      runInShell: true,
    );

    expect(result.exitCode, 0);

    // check "firebase_options.dart" file is created in lib directory
    final firebaseOptions =
        p.join(projectPath!, 'lib', 'firebase_options.dart');

    await testFirebaseOptionsFileValues(
      firebaseOptions,
      selectedPlatform: kWindows,
    );
  });

  test(
    'flutterfire configure: check Dart file configuration is updated correctly',
    () async {
      // Set up  initial configuration
      final result = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          // Only configuring android initially
          '--platforms=android',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
          '--windows-app-id=$windowsAppId',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        fail(result.stderr as String);
      }

      final firebaseOptions = p.join(
        projectPath!,
        'lib',
        'firebase_options.dart',
      );

      // check "firebase_options.dart" file was created and updates android only
      final firebaseOptionsContent = await File(firebaseOptions).readAsString();

      // only configure android initially
      final listOfStrings = firebaseOptionsContent.split('\n');
      expect(
        listOfStrings,
        containsAll(<Matcher>[
          contains(androidAppId),
          contains('static const FirebaseOptions android = FirebaseOptions'),
        ]),
      );
      expect(
        firebaseOptionsContent
            .contains('static const FirebaseOptions web = FirebaseOptions'),
        isFalse,
      );
      expect(
        firebaseOptionsContent
            .contains('static const FirebaseOptions ios = FirebaseOptions'),
        isFalse,
      );

      // Now reconfigure with ios, macos & web platforms and check Dart file is updated correctly
      final result2 = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          // Configure the rest of the platforms
          '--platforms=ios,macos,web',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
          '--windows-app-id=$windowsAppId',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result2.exitCode != 0) {
        fail(result.stderr as String);
      }

      final firebaseOptionsContent2 =
          await File(firebaseOptions).readAsString();
      final listOfStrings2 = firebaseOptionsContent2.split('\n');

      expect(
        listOfStrings2,
        containsAll(<Matcher>[
          contains(androidAppId),
          contains('static const FirebaseOptions web = FirebaseOptions'),
          contains('static const FirebaseOptions android = FirebaseOptions'),
          contains('static const FirebaseOptions ios = FirebaseOptions'),
        ]),
      );

      final startIndexWeb = listOfStrings2.indexWhere(
        (line) => line.contains(
          'if (kIsWeb)',
        ),
      );

      listOfStrings2[startIndexWeb + 1].contains(
        'return web;',
      );

      final startIndexAndroid = listOfStrings2.indexWhere(
        (line) => line.contains(
          'case TargetPlatform.android:',
        ),
      );

      listOfStrings2[startIndexAndroid + 1].contains(
        'return android;',
      );

      final startIndexIos = listOfStrings2.indexWhere(
        (line) => line.contains(
          'case TargetPlatform.iOS:',
        ),
      );

      listOfStrings2[startIndexIos + 1].contains(
        'return ios;',
      );

      final startIndexMacos = listOfStrings2.indexWhere(
        (line) => line.contains(
          'case TargetPlatform.macOS:',
        ),
      );

      listOfStrings2[startIndexMacos + 1].contains(
        'return macos;',
      );

      // Now reconfigure with different apps across platforms and check Dart file is updated correctly
      final result3 = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--platforms=ios,macos,web,android,windows',
          '--ios-bundle-id=$secondAppleBundleId',
          '--android-package-name=$secondAndroidApplicationId',
          '--macos-bundle-id=$secondAppleBundleId',
          '--web-app-id=$secondWebAppId',
          '--windows-app-id=$secondWindowsAppId',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result3.exitCode != 0) {
        fail(result.stderr as String);
      }

      final firebaseOptionsContent3 =
          await File(firebaseOptions).readAsString();
      final listOfStrings3 = firebaseOptionsContent3.split('\n');

      expect(
        listOfStrings3,
        containsAll(<Matcher>[
          contains(secondAndroidAppId),
          contains(secondAppleAppId),
          contains(secondWebAppId),
          contains(secondWindowsAppId),
        ]),
      );
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

  test(
      'flutterfire configure: ensure android build.gradle files are only updated once',
      () async {
    // Add crashlytics and performance to check they are only created once
    final result = Process.runSync(
      'flutter',
      ['pub', 'add', 'firebase_crashlytics', 'firebase_performance'],
      workingDirectory: projectPath,
    );

    if (result.exitCode != 0) {
      fail(result.stderr as String);
    }
    // Run first time to update
    Process.runSync(
      'flutterfire',
      [
        'configure',
        '--yes',
        // Only android
        '--platforms=android',
        '--ios-bundle-id=com.example.flutterTestCli',
        '--android-package-name=com.example.flutter_test_cli',
        '--macos-bundle-id=com.example.flutterTestCli',
        '--web-app-id=$webAppId',
        '--windows-app-id=$windowsAppId',
        '--project=$firebaseProjectId',
      ],
      workingDirectory: projectPath,
      runInShell: true,
    );
    // Run second time and check it was only updated once
    final result2 = Process.runSync(
      'flutterfire',
      [
        'configure',
        '--yes',
        // Only android
        '--platforms=android',
        '--ios-bundle-id=com.example.flutterTestCli',
        '--android-package-name=com.example.flutter_test_cli',
        '--macos-bundle-id=com.example.flutterTestCli',
        '--web-app-id=$webAppId',
        '--windows-app-id=$windowsAppId',
        '--project=$firebaseProjectId',
      ],
      workingDirectory: projectPath,
      runInShell: true,
    );

    if (result2.exitCode != 0) {
      fail(result2.stderr as String);
    }

    await checkBuildGradleFileUpdated(
      projectPath!,
      checkCrashlytics: true,
      checkPerf: true,
    );
  });
}
