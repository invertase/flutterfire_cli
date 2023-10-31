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
          '--platforms=android,ios,macos,web',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
          '--project=$firebaseProjectId',
        ],
        workingDirectory: projectPath,
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
      testAndroidServiceFileValues(androidServiceFilePath);

      // Check android "android/build.gradle" & "android/app/build.gradle" were updated

      final androidBuildGradle =
          p.join(projectPath!, 'android', 'build.gradle');
      final androidAppBuildGradle =
          p.join(projectPath!, 'android', 'app', 'build.gradle');

      final androidBuildGradleContent =
          await File(androidBuildGradle).readAsString();

      final androidAppBuildGradleContent =
          await File(androidAppBuildGradle).readAsString();

      final buildGradleLines = androidGradleUpdate.trim().split('\n');

      expect(
        containsInOrder(androidBuildGradleContent, buildGradleLines),
        isTrue,
      );

      final appBuildGradleLines = androidAppGradleUpdate.trim().split('\n');

      expect(
        containsInOrder(androidAppBuildGradleContent, appBuildGradleLines),
        isTrue,
      );

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
          '--platforms=android,ios,macos,web',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
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

      // Check android "android/build.gradle" & "android/app/build.gradle" were updated
      final androidBuildGradle =
          p.join(projectPath!, 'android', 'build.gradle');
      final androidAppBuildGradle =
          p.join(projectPath!, 'android', 'app', 'build.gradle');

      final androidBuildGradleContent =
          await File(androidBuildGradle).readAsString();

      final androidAppBuildGradleContent =
          await File(androidAppBuildGradle).readAsString();

      final buildGradleLines = androidGradleUpdate.trim().split('\n');

      expect(
        containsInOrder(androidBuildGradleContent, buildGradleLines),
        isTrue,
      );

      final appBuildGradleLines = androidAppGradleUpdate.trim().split('\n');

      expect(
        containsInOrder(androidAppBuildGradleContent, appBuildGradleLines),
        isTrue,
      );

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
          '--platforms=android,ios,macos,web',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
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
        androidBuildConfiguration,
        'google-services.json',
      );
      testAndroidServiceFileValues(androidServiceFilePath);

      // Check android "android/build.gradle" & "android/app/build.gradle" were updated
      final androidBuildGradle =
          p.join(projectPath!, 'android', 'build.gradle');
      final androidAppBuildGradle =
          p.join(projectPath!, 'android', 'app', 'build.gradle');

      final androidBuildGradleContent =
          await File(androidBuildGradle).readAsString();

      final androidAppBuildGradleContent =
          await File(androidAppBuildGradle).readAsString();

      final buildGradleLines = androidGradleUpdate.trim().split('\n');

      expect(
        containsInOrder(androidBuildGradleContent, buildGradleLines),
        isTrue,
      );

      final appBuildGradleLines = androidAppGradleUpdate.trim().split('\n');

      expect(
        containsInOrder(androidAppBuildGradleContent, appBuildGradleLines),
        isTrue,
      );

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
          '--platforms=android,ios,macos,web',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
        ],
        workingDirectory: projectPath,
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
        ],
        workingDirectory: projectPath,
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
          '--platforms=android,ios,macos,web',
          '--ios-bundle-id=com.example.secondApp',
          '--android-package-name=com.example.second_app',
          '--macos-bundle-id=com.example.secondApp',
          '--web-app-id=$secondWebAppId',
        ],
        workingDirectory: projectPath,
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
          contains('static const FirebaseOptions web = FirebaseOptions'),
          contains('static const FirebaseOptions android = FirebaseOptions'),
          contains('static const FirebaseOptions ios = FirebaseOptions'),
          contains('static const FirebaseOptions macos = FirebaseOptions'),
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
          '--project=$firebaseProjectId',
        ],
        workingDirectory: projectPath,
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
        ],
        workingDirectory: projectPath,
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

      // Clean out file to test it was recreated
      await File(firebaseOptions).writeAsString('');

      final accessToken = await generateAccessTokenCI();
      // Perform `flutterfire configure` without args to use `flutterfire reconfigure`.
      final result2 = Process.runSync(
        'flutterfire',
        [
          'configure',
          if (accessToken != null) '--test-access-token=$accessToken',
        ],
        workingDirectory: projectPath,
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
          '--platforms=android,ios,macos,web',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=$webAppId',
          // Output to different file
          '--out=lib/$configurationFileName',
        ],
        workingDirectory: projectPath,
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
          contains('static const FirebaseOptions android = FirebaseOptions'),
          contains('static const FirebaseOptions ios = FirebaseOptions'),
          contains('static const FirebaseOptions web = FirebaseOptions'),
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
        '--android-package-name=com.example.flutter_test_cli',
        '--macos-bundle-id=com.example.flutterTestCli',
      ],
      workingDirectory: projectPath,
    );

    expect(result.exitCode != 0, isTrue);
    expect(
      (result.stderr as String).contains(
        'does not match the web app id of any existing Firebase app',
      ),
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
      ],
      workingDirectory: projectPath,
    );

    expect(result.exitCode, 0);
    // Console out put looks like this on success: "web       1:262904632156:web:cb3a00412ed430ca2f2799"
    expect(
      (result.stdout as String).contains(
        'web       $secondWebAppId',
      ),
      isTrue,
    );
  });
}
