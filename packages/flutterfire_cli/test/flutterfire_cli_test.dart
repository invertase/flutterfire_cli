import 'dart:convert';
import 'dart:io';

import 'package:flutterfire_cli/src/common/utils.dart' as utils;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const firebaseProjectId = 'flutterfire-cli-test-f6f57';
  const testFileDirectory = 'test_files';
  Directory? tempDir;

  Future<String> createFlutterProject() async {
    // final tempDir = utils.isCI
    //     ? Directory(Platform.environment['RUNNER_TEMP'] ?? '.')
    //     : Directory.systemTemp.createTempSync();

    tempDir = Directory.systemTemp.createTempSync();
    const flutterProject = 'flutter_test_cli';
    await Process.run(
      'flutter',
      ['create', flutterProject],
      workingDirectory: tempDir!.path,
    );

    final updatedPath = p.join(tempDir!.path, flutterProject);
    return updatedPath;
  }

  String removeWhitepaceAndNewLines(String string) {
    return string.replaceAll(RegExp(r'\s+|\n'), '');
  }

  String generateRubyScriptForTesting(
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
        
        # find "GoogleService-Info.plist" bundled with resources
        serviceFileInResources = target.resources_build_phase.files.find do |file|
          if defined? file && file.file_ref && file.file_ref.path
            if file.file_ref.path.is_a? String
              file.file_ref.path.include? 'GoogleService-Info.plist'
            end
          end
        end
        if(serviceFileInResources && debugSymbolScript)
          \$stdout.write("success")
        else
          if(!debugSymbolScript)
            abort("failed, cannot find debug symbol script #{debugSymbolScriptName} in run script build phases")
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

  Future<File> findFileInDirectory(
      String directoryPath, String fileName) async {
    final directory = Directory(directoryPath);
    if (directory.existsSync()) {
      List contents = directory.listSync();
      for (final entity in contents) {
        if (entity is File && entity.path.endsWith(fileName)) {
          return entity;
        }
      }
    } else {
      throw Exception('Directory does not exist: ${directory.path}}');
    }

    throw Exception('File not found: ${fileName}}');
  }

  test(
    'flutterfire configure --yes --project=$firebaseProjectId --debug-symbols-ios --debug-symbols-macos',
    () async {
      final projectPath = await createFlutterProject();
      // the most basic 'flutterfire configure' command that can be run without command line prompts

      final result = Process.runSync(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseProjectId',
          '--debug-symbols-ios',
          '--debug-symbols-macos',
          // The below args aren't needed unless running from CI. We need for Github actions to run command.
          '--platforms=android,ios,macos,web',
          '--ios-bundle-id=com.example.flutterTestCli',
          '--android-package-name=com.example.flutter_test_cli',
          '--macos-bundle-id=com.example.flutterTestCli',
          '--web-app-id=com.example.flutterTestCli',
        ],
        workingDirectory: projectPath,
      );

      print('STDOUT: ${result.stdout}');
      print('STDERR: ${result.stderr}');

      // check Apple service files were created and have correct content
      final iosPath = p.join(projectPath, 'ios');
      final macosPath = p.join(projectPath, 'macos', 'Runner');
      const defaultServiceFile = 'Runner/GoogleService-Info.plist';
      final iosServiceFile = p.join(iosPath, defaultServiceFile);
      final macosServiceFile = p.join(macosPath, defaultServiceFile);

      final testServiceFile = p.join(
        Directory.current.path,
        'test',
        testFileDirectory,
        'GoogleService-Info.plist',
      );

      final macFile =
          await findFileInDirectory(macosPath, 'GoogleService-Info.plist');

          print('MMMMMM: ${macFile.path}');
      final iosServiceFileContent = await File(iosServiceFile).readAsString();
      // final macosServiceFileContent = await macFile.readAsString();

      final testServiceFileContent = await File(testServiceFile).readAsString();

      expect(iosServiceFileContent, testServiceFileContent);
      // expect(macosServiceFileContent, testServiceFileContent);

      print('HHHHHHHHH');
      // check default "firebase.json" was created and has correct content
      // final firebaseJsonFile = p.join(projectPath, 'firebase.json');

      // final testFirebaseJsonFile = p.join(
      //   Directory.current.path,
      //   'test',
      //   testFileDirectory,
      //   'default_firebase.json',
      // );
      // final firebaseJsonFileContent = await File(firebaseJsonFile).readAsString();
      // final testFirebaseJsonFileContent =
      //     await File(testFirebaseJsonFile).readAsString();
      // // need to remove whitespace and newline characters to compare
      // expect(
      //   firebaseJsonFileContent,
      //   removeWhitepaceAndNewLines(testFirebaseJsonFileContent),
      // );

      // check google-services.json was created and has correct content
//     final androidServiceFilePath = p.join(
//       projectPath,
//       'android',
//       'app',
//       'google-services.json',
//     );
//     final testAndroidServiceFilePath = p.join(
//       Directory.current.path,
//       'test',
//       testFileDirectory,
//       'google-services.json',
//     );
//     final androidServiceFileContent =
//         await File(androidServiceFilePath).readAsString();

//     final testAndroidServiceFileContent =
//         await File(testAndroidServiceFilePath).readAsString();

//     expect(androidServiceFileContent, testAndroidServiceFileContent);

//     // Check android "android/build.gradle" & "android/app/build.gradle" were updated
//     const androidGradleUpdate = '''
//         // START: FlutterFire Configuration
//         classpath 'com.google.gms:google-services:4.3.10'
//         // END: FlutterFire Configuration
// ''';

//     const androidAppGradleUpdate = '''
//         // START: FlutterFire Configuration
//         apply plugin: 'com.google.gms.google-services'
//         // END: FlutterFire Configuration
//         ''';

//     final androidBuildGradle = p.join(projectPath, 'android', 'build.gradle');
//     final androidAppBuildGradle =
//         p.join(projectPath, 'android', 'app', 'build.gradle');

//     final androidBuildGradleContent =
//         await File(androidBuildGradle).readAsString();

//     final androidAppBuildGradleContent =
//         await File(androidAppBuildGradle).readAsString();

//     expect(
//       removeWhitepaceAndNewLines(androidBuildGradleContent),
//       contains(removeWhitepaceAndNewLines(androidGradleUpdate)),
//     );
//     expect(
//       removeWhitepaceAndNewLines(androidAppBuildGradleContent),
//       contains(removeWhitepaceAndNewLines(androidAppGradleUpdate)),
//     );

//     // check "firebase_options.dart" file is created in lib directory
//     final firebaseOptions = p.join(projectPath, 'lib', 'firebase_options.dart');
//     final testFirebaseOptions = p.join(
//       Directory.current.path,
//       'test',
//       testFileDirectory,
//       'firebase_options.dart',
//     );

//     final firebaseOptionsContent = await File(firebaseOptions).readAsString();
//     final testFirebaseOptionsContent =
//         await File(testFirebaseOptions).readAsString();

//     expect(firebaseOptionsContent, testFirebaseOptionsContent);

//     // check GoogleService-Info.plist file & debug symbols script is added to Apple "project.pbxproj" files
//     final iosXcodeProject = p.join(
//       projectPath,
//       'ios',
//       'Runner.xcodeproj',
//     );

//     final scriptToCheckIosPbxprojFile =
//         generateRubyScriptForTesting(iosXcodeProject);

//     final iosResult = Process.runSync(
//       'ruby',
//       [
//         '-e',
//         scriptToCheckIosPbxprojFile,
//       ],
//     );

//     if (iosResult.exitCode != 0) {
//       fail(iosResult.stderr as String);
//     }

//     expect(iosResult.stdout, 'success');

//     final macosXcodeProject = p.join(
//       projectPath,
//       'macos',
//       'Runner.xcodeproj',
//     );

//     final scriptToCheckMacosPbxprojFile = generateRubyScriptForTesting(
//       macosXcodeProject,
//     );

//     final macosResult = Process.runSync(
//       'ruby',
//       [
//         '-e',
//         scriptToCheckMacosPbxprojFile,
//       ],
//     );

//     if (macosResult.exitCode != 0) {
//       fail(macosResult.stderr as String);
//     }

//     expect(macosResult.stdout, 'success');

      addTearDown(() => tempDir!.delete(recursive: true));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test('Run "flutterfire configure" to update values', () async {
    // final projectPath = await createFlutterProject();
    // // initial setup before updating values
    // Process.runSync(
    //   'flutterfire',
    //   [
    //     'configure',
    //     '--yes',
    //     '--project=$firebaseProjectId',
    //     '--debug-symbols-ios',
    //     '--debug-symbols-macos'
    //   ],
    //   workingDirectory: projectPath,
    // );

    // TODO - update values and test they are updated correctly
  });
}
