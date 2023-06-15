import 'dart:convert';
import 'dart:io';

import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:flutterfire_cli/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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
      Process.runSync(
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
          '--web-app-id=com.example.flutterTestCli',
        ],
        workingDirectory: projectPath,
      );

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
      const androidGradleUpdate = '''
        // START: FlutterFire Configuration
        classpath 'com.google.gms:google-services:4.3.10'
        // END: FlutterFire Configuration
''';

      const androidAppGradleUpdate = '''
        // START: FlutterFire Configuration
        apply plugin: 'com.google.gms.google-services'
        // END: FlutterFire Configuration
        ''';

      final androidBuildGradle =
          p.join(projectPath!, 'android', 'build.gradle');
      final androidAppBuildGradle =
          p.join(projectPath!, 'android', 'app', 'build.gradle');

      final androidBuildGradleContent =
          await File(androidBuildGradle).readAsString();

      final androidAppBuildGradleContent =
          await File(androidAppBuildGradle).readAsString();

      expect(
        removeWhitepaceAndNewLines(androidBuildGradleContent),
        contains(removeWhitepaceAndNewLines(androidGradleUpdate)),
      );
      expect(
        removeWhitepaceAndNewLines(androidAppBuildGradleContent),
        contains(removeWhitepaceAndNewLines(androidAppGradleUpdate)),
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
      Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          // Android just requires the `--android-out` flag to be set
          '--android-out=android/app/$buildType',
          // Apple required the `--ios-out` and `--macos-out` flags to be set & the build type,
          // We're using `Debug` for both which is a standard build configuration for an apple Flutter app
          '--ios-out=ios/$buildType',
          '--ios-build-config=$appleBuildConfiguration',
          '--macos-out=macos/$buildType',
          '--macos-build-config=$appleBuildConfiguration',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--platforms=android,ios,macos,web',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=com.example.flutterTestCli',
        ],
        workingDirectory: projectPath,
      );

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
      const androidGradleUpdate = '''
        // START: FlutterFire Configuration
        classpath 'com.google.gms:google-services:4.3.10'
        // END: FlutterFire Configuration
''';

      const androidAppGradleUpdate = '''
        // START: FlutterFire Configuration
        apply plugin: 'com.google.gms.google-services'
        // END: FlutterFire Configuration
        ''';

      final androidBuildGradle =
          p.join(projectPath!, 'android', 'build.gradle');
      final androidAppBuildGradle =
          p.join(projectPath!, 'android', 'app', 'build.gradle');

      final androidBuildGradleContent =
          await File(androidBuildGradle).readAsString();

      final androidAppBuildGradleContent =
          await File(androidAppBuildGradle).readAsString();

      expect(
        removeWhitepaceAndNewLines(androidBuildGradleContent),
        contains(removeWhitepaceAndNewLines(androidGradleUpdate)),
      );
      expect(
        removeWhitepaceAndNewLines(androidAppBuildGradleContent),
        contains(removeWhitepaceAndNewLines(androidAppGradleUpdate)),
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
      Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          // Android just requires the `--android-out` flag to be set
          '--android-out=android/app/$androidBuildConfiguration',
          // Apple required the `--ios-out` and `--macos-out` flags to be set & the build type,
          // We're using `Runner` target for both which is the standard target for an apple Flutter app
          '--ios-out=ios/$applePath',
          '--ios-target=$targetType',
          '--macos-out=macos/$applePath',
          '--macos-target=$targetType',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--platforms=android,ios,macos,web',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=com.example.flutterTestCli',
        ],
        workingDirectory: projectPath,
      );

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
      const androidGradleUpdate = '''
        // START: FlutterFire Configuration
        classpath 'com.google.gms:google-services:4.3.10'
        // END: FlutterFire Configuration
''';

      const androidAppGradleUpdate = '''
        // START: FlutterFire Configuration
        apply plugin: 'com.google.gms.google-services'
        // END: FlutterFire Configuration
        ''';

      final androidBuildGradle =
          p.join(projectPath!, 'android', 'build.gradle');
      final androidAppBuildGradle =
          p.join(projectPath!, 'android', 'app', 'build.gradle');

      final androidBuildGradleContent =
          await File(androidBuildGradle).readAsString();

      final androidAppBuildGradleContent =
          await File(androidAppBuildGradle).readAsString();

      expect(
        removeWhitepaceAndNewLines(androidBuildGradleContent),
        contains(removeWhitepaceAndNewLines(androidGradleUpdate)),
      );
      expect(
        removeWhitepaceAndNewLines(androidAppBuildGradleContent),
        contains(removeWhitepaceAndNewLines(androidAppGradleUpdate)),
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
      Process.runSync(
        'flutter',
        ['pub', 'add', 'firebase_crashlytics'],
        workingDirectory: projectPath,
      );

      Process.runSync(
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
          '--web-app-id=com.example.flutterTestCli',
        ],
        workingDirectory: projectPath,
      );
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
      Process.runSync(
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
          '--web-app-id=com.example.flutterTestCli',
        ],
        workingDirectory: projectPath,
      );

      // The second configuration with different bundle ids which we need to check
      Process.runSync(
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
          '--web-app-id=com.example.secondApp',
        ],
        workingDirectory: projectPath,
      );

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

      Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--platforms=android,ios',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=com.example.flutterTestCli',
        ],
        workingDirectory: projectPath,
      );

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
        firebaseOptionsContent.contains('static const FirebaseOptions web = FirebaseOptions'),
        isFalse,
      );
      
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );
}
