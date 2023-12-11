import 'dart:io';
import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:flutterfire_cli/src/common/utils.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'test_utils.dart';

Future<String?> generateAccessTokenCI() async {
  // If it's not on the CI, this won't be present, and it will run as normal
  final serviceAccount = Platform.environment['FIREBASE_SERVICE_ACCOUNT'];

  if (serviceAccount == null) {
    return null;
  }

  final credentials = ServiceAccountCredentials.fromJson(serviceAccount);

  // Authenticate with the Google Auth Library
  final scopes = [
    'https://www.googleapis.com/auth/firebase',
  ];
  final client = await clientViaServiceAccount(credentials, scopes);

  // Return the access token
  return client.credentials.accessToken.data;
}

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
      // 1. Run "flutterfire configure" to setup
      // 2. Delete "firebase_options.dart", "google-services.json" & "GoogleService-Info.plist"
      // 3. Run "flutterfire reconfigure" which will use the "firebase.json" file to regenerate the deleted files
      // 4. Check the files have been recreated via "flutterfire reconfigure"

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
        fail(result.stderr);
      }

      final addDependencies = Process.runSync(
        'flutter',
        [
          'pub',
          'add',
          'firebase_crashlytics',
          'firebase_performance',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (addDependencies.exitCode != 0) {
        fail(addDependencies.stderr);
      }

      String? iosPath;
      String? macosPath;
      if (Platform.isMacOS) {
        iosPath = p.join(
          projectPath!,
          kIos,
          defaultTarget,
          appleServiceFileName,
        );
        macosPath = p.join(projectPath!, kMacos, defaultTarget);

        final macFile =
            await findFileInDirectory(macosPath, appleServiceFileName);

        await File(iosPath).delete();
        await macFile.delete();
        // Clean up the project files to ensure the reconfigure command works
        await cleanXcodeProjFiles(projectPath!);
      }
      final firebaseOptionsPath =
          p.join(projectPath!, 'lib', 'firebase_options.dart');
      final androidServiceFilePath = p.join(
        projectPath!,
        'android',
        'app',
        androidServiceFileName,
      );
      await File(firebaseOptionsPath).delete();
      await File(androidServiceFilePath).delete();

      final accessToken = await generateAccessTokenCI();

      // Clean up the project files to ensure the reconfigure command works
      await cleanBuildGradleFiles(projectPath!);

      final result2 = Process.runSync(
        'flutterfire',
        [
          'reconfigure',
          if (accessToken != null) '--ci-access-token=$accessToken',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result2.exitCode != 0) {
        fail(result2.stderr);
      }

      testAndroidServiceFileValues(androidServiceFilePath);
      await testFirebaseOptionsFileValues(firebaseOptionsPath);
      await checkBuildGradleFileUpdated(
        projectPath!,
        checkCrashlytics: true,
        checkPerf: true,
      );

      if (Platform.isMacOS) {
        await testAppleServiceFileValues(iosPath!);
        await testAppleServiceFileValues(
          macosPath!,
          platform: kMacos,
        );
        await checkXcodeProjFiles(projectPath!);
      }
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
        fail(result.stderr);
      }

      final addDependencies = Process.runSync(
        'flutter',
        [
          'pub',
          'add',
          'firebase_crashlytics',
          'firebase_performance',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (addDependencies.exitCode != 0) {
        fail(addDependencies.stderr);
      }

      String? iosPath;
      String? macosPath;
      if (Platform.isMacOS) {
        iosPath = p.join(
          projectPath!,
          kIos,
          buildType,
          appleServiceFileName,
        );
        macosPath = p.join(
          projectPath!,
          kMacos,
          buildType,
        );

        final macFile =
            await findFileInDirectory(macosPath, appleServiceFileName);

        await File(iosPath).delete();
        await macFile.delete();
        // Clean up the project files to ensure the reconfigure command works
        await cleanXcodeProjFiles(projectPath!);
      }
      final firebaseOptionsPath =
          p.join(projectPath!, 'lib', 'firebase_options.dart');
      final androidServiceFilePath = p.join(
        projectPath!,
        'android',
        'app',
        buildType,
        androidServiceFileName,
      );

      await File(firebaseOptionsPath).delete();
      await File(androidServiceFilePath).delete();
      // Clean up the project files to ensure the reconfigure command works
      await cleanBuildGradleFiles(projectPath!);

      final accessToken = await generateAccessTokenCI();

      final result2 = Process.runSync(
        'flutterfire',
        [
          'reconfigure',
          if (accessToken != null) '--ci-access-token=$accessToken',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result2.exitCode != 0) {
        fail(result2.stderr);
      }

      testAndroidServiceFileValues(androidServiceFilePath);
      await testFirebaseOptionsFileValues(firebaseOptionsPath);
      await checkBuildGradleFileUpdated(
        projectPath!,
        checkCrashlytics: true,
        checkPerf: true,
      );

      if (Platform.isMacOS) {
        await testAppleServiceFileValues(iosPath!);
        await testAppleServiceFileValues(
          macosPath!,
          platform: kMacos,
        );
        await checkXcodeProjFiles(projectPath!);
      }
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
        fail(result.stderr);
      }

      final addDependencies = Process.runSync(
        'flutter',
        [
          'pub',
          'add',
          'firebase_crashlytics',
          'firebase_performance',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (addDependencies.exitCode != 0) {
        fail(addDependencies.stderr);
      }

      String? iosPath;
      String? macosPath;
      if (Platform.isMacOS) {
        iosPath = p.join(
          projectPath!,
          kIos,
          applePath,
          appleServiceFileName,
        );
        macosPath = p.join(
          projectPath!,
          kMacos,
          applePath,
        );

        final macFile =
            await findFileInDirectory(macosPath, appleServiceFileName);

        await File(iosPath).delete();
        await macFile.delete();
        // Clean up the project files to ensure the reconfigure command works
        await cleanXcodeProjFiles(projectPath!);
      }
      final firebaseOptionsFile = await findFileInDirectory(
        p.join(projectPath!, 'lib'),
        'firebase_options.dart',
      );

      final androidServiceFilePath = p.join(
        projectPath!,
        'android',
        'app',
        androidBuildConfiguration,
        'google-services.json',
      );

      await firebaseOptionsFile.delete();
      await File(androidServiceFilePath).delete();

      final accessToken = await generateAccessTokenCI();

      // Clean up the project files to ensure the reconfigure command works
      await cleanBuildGradleFiles(projectPath!);

      final result2 = Process.runSync(
        'flutterfire',
        [
          'reconfigure',
          if (accessToken != null) '--ci-access-token=$accessToken',
        ],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result2.exitCode != 0) {
        fail(result.stderr);
      }

      testAndroidServiceFileValues(androidServiceFilePath);
      final firebaseOptionsPath =
          p.join(projectPath!, 'lib', 'firebase_options.dart');
      await testFirebaseOptionsFileValues(firebaseOptionsPath);

      await checkBuildGradleFileUpdated(
        projectPath!,
        checkCrashlytics: true,
        checkPerf: true,
      );

      if (Platform.isMacOS) {
        await testAppleServiceFileValues(iosPath!);
        await testAppleServiceFileValues(
          macosPath!,
          platform: kMacos,
        );
        await checkXcodeProjFiles(projectPath!);
      }
    },
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );
}
