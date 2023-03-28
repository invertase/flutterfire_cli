import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const firebaseProjectId = 'flutterfire-cli-test-f6f57';
  const testFileDirectory = 'test_files';

  Future<String> createFlutterProject() async {
    final tempDir = Directory.systemTemp.createTempSync();
    const flutterProject = 'flutter_test_cli';
    await Process.run(
      'flutter',
      ['create', flutterProject],
      workingDirectory: tempDir.path,
    );

    return p.join(tempDir.path, flutterProject);
  }

  String removeWhitepaceAndNewLines(String string) {
    return string.replaceAll(RegExp(r'\s+|\n'), '');
  }

  String rubyScriptForTestingDefaultConfigure(
    String projectPath, {
    String targetName = 'Runner',
    String debugSymbolScriptName =
        'FlutterFire: "flutterfire upload-crashlytics-symbols"',
  }) {
    return '''
      require 'xcodeproj'
      xcodeFile='$projectPath'
      debugSymbolScriptName='$debugSymbolScriptName'
      targetName='$targetName'
      project = Xcodeproj::Project.open(xcodeFile)
      target = project.targets.find { |target| target.name == targetName }
      if(target)
        # ensure debug symbol script does not exist in build phase scripts
        debugSymbolScript = target.shell_script_build_phases().find do |script|
          if defined? script && script.name
            script.name == debugSymbolScriptName
          end
        end
        
        # find "GoogleService-Info.plist" bundled with resources
        serviceFileInResources = target.resources_build_phase.files.find do |file|
          if defined? file && file.file_ref && file.file_ref.path
            if file.file_ref.path.is_a? String
              file.file_ref.path.include? 'GoogleService-Info.plist'
            end
          end
        end
        if(serviceFileInResources && !debugSymbolScript)
          \$stdout.write("success")
        else
          if(debugSymbolScript)
            abort("failed, debug symbol script #{debugSymbolScriptName} exists in run script build phases")
          end
          if(!serviceFileInResources)
            abort("failed, cannot find 'GoogleService-Info.plist' bundled in resources")
          end
        end
      else
        abort("failed, #{targetName} target not found.")
      end
''';
  }

  String rubyScriptForTestingDebugSymbolScriptExists(
    String projectPath, {
    String targetName = 'Runner',
    String debugSymbolScriptName =
        'FlutterFire: "flutterfire upload-crashlytics-symbols"',
  }) {
    return '''
      require 'xcodeproj'
      xcodeFile='$projectPath'
      debugSymbolScriptName='$debugSymbolScriptName'
      targetName='$targetName'
      project = Xcodeproj::Project.open(xcodeFile)
      target = project.targets.find { |target| target.name == targetName }
      if(target)
        # find debug symbol script in build phase scripts
        debugSymbolScript = target.shell_script_build_phases().find do |script|
          if defined? script && script.name
            script.name == debugSymbolScriptName
          end
        end
        
        if(debugSymbolScript)
          \$stdout.write("success")
        else
          abort("failed, cannot find debug symbol script #{debugSymbolScriptName} in run script build phases")
        end
      else
        abort("failed, #{targetName} target not found.")
      end
''';
  }

  Future<File> findFileInDirectory(
    String directoryPath,
    String fileName,
  ) async {
    final directory = Directory(directoryPath);
    if (directory.existsSync()) {
      final contents = directory.listSync();
      for (final entity in contents) {
        if (entity is File && entity.path.endsWith(fileName)) {
          return entity;
        }
      }
    } else {
      throw Exception('Directory does not exist: ${directory.path}}');
    }

    throw Exception('File not found: $fileName');
  }

  String? projectPath;
  setUpAll(() async {
    projectPath = await createFlutterProject();
  });

  tearDownAll(() {
    Directory(p.dirname(projectPath!)).delete(recursive: true);
  });

  test(
    'flutterfire configure --yes --project=$firebaseProjectId --debug-symbols-ios --debug-symbols-macos',
    () async {
      // the most basic 'flutterfire configure' command that can be run without command line prompts

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
        final iosPath = p.join(projectPath!, 'ios');
        final macosPath = p.join(projectPath!, 'macos', 'Runner');
        const defaultServiceFile = 'Runner/GoogleService-Info.plist';
        final iosServiceFile = p.join(iosPath, defaultServiceFile);

        final testServiceFile = p.join(
          Directory.current.path,
          'test',
          testFileDirectory,
          'GoogleService-Info.plist',
        );
        // Need to find mac file like this for it to work on CI
        final macFile =
            await findFileInDirectory(macosPath, 'GoogleService-Info.plist');

        final iosServiceFileContent = await File(iosServiceFile).readAsString();
        final macosServiceFileContent = await macFile.readAsString();

        final testServiceFileContent =
            await File(testServiceFile).readAsString();

        expect(iosServiceFileContent, testServiceFileContent);
        expect(macosServiceFileContent, testServiceFileContent);

        // check default "firebase.json" was created and has correct content
        final firebaseJsonFile = p.join(projectPath!, 'firebase.json');

        final testFirebaseJsonFile = p.join(
          Directory.current.path,
          'test',
          testFileDirectory,
          'default_firebase.json',
        );
        final firebaseJsonFileContent =
            await File(firebaseJsonFile).readAsString();
        final testFirebaseJsonFileContent =
            await File(testFirebaseJsonFile).readAsString();
        // need to remove whitespace and newline characters to compare
        expect(
          firebaseJsonFileContent,
          removeWhitepaceAndNewLines(testFirebaseJsonFileContent),
        );

        // check GoogleService-Info.plist file is included & debug symbols script (until firebase crashlytics is a dependency) is not included in Apple "project.pbxproj" files
        final iosXcodeProject = p.join(
          projectPath!,
          'ios',
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
          'macos',
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
        'google-services.json',
      );
      final testAndroidServiceFilePath = p.join(
        Directory.current.path,
        'test',
        testFileDirectory,
        'google-services.json',
      );
      final androidServiceFileContent =
          await File(androidServiceFilePath).readAsString();

      final testAndroidServiceFileContent =
          await File(testAndroidServiceFilePath).readAsString();

      expect(androidServiceFileContent, testAndroidServiceFileContent);

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
      final testFirebaseOptions = p.join(
        Directory.current.path,
        'test',
        testFileDirectory,
        'firebase_options.dart',
      );

      final firebaseOptionsContent = await File(firebaseOptions).readAsString();
      final testFirebaseOptionsContent =
          await File(testFirebaseOptions).readAsString();

      expect(firebaseOptionsContent, testFirebaseOptionsContent);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('Validate service file requirements for iOS platform', () async {
    final result = Process.runSync(
      'flutterfire',
      [
        'configure',
        // Incorrect service file name
        '--ios-out=something/not-service-file.plist',
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

    expect(result.exitCode, 1);
    expect(
      result.stderr,
      contains(
        'ServiceFileRequirementException: ios - The service file name must be `GoogleService-Info.plist`',
      ),
    );
  });
  test('Validate service file requirements for macOS platform', () {
    final result = Process.runSync(
      'flutterfire',
      [
        'configure',
        // Incorrect service file name
        '--macos-out=something/not-service-file.plist',
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

    expect(result.exitCode, 1);
    expect(
      result.stderr,
      contains(
        'ServiceFileRequirementException: macos - The service file name must be `GoogleService-Info.plist`',
      ),
    );
  });

  test('Validate service file requirements for android platform', () {
    final result = Process.runSync(
      'flutterfire',
      [
        'configure',
        // Incorrect service file name
        '--android-out=android/app/not-service-file.json',
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

    expect(result.exitCode, 1);
    expect(
      result.stderr,
      contains(
        'ServiceFileRequirementException: android - The service file name must be `google-services.json`',
      ),
    );
  });

  test('Validate service file path for android platform', () {
    final result1 = Process.runSync(
      'flutterfire',
      [
        'configure',
        // Requires "app" path segment
        '--android-out=android/google-services.json',
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

    expect(result1.exitCode, 1);
    expect(
      result1.stderr,
      contains(
        'ServiceFileRequirementException: android - The service file name must contain `android/app`',
      ),
    );

    final result2 = Process.runSync(
      'flutterfire',
      [
        'configure',
        // Requires "android" path segment
        '--android-out=app/google-services.json',
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

    expect(result2.exitCode, 1);
    expect(
      result2.stderr,
      contains(
        'The file path for the Android service file must contain `android/app`',
      ),
    );
  });

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
        'ios',
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
        'macos',
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
  );
}
