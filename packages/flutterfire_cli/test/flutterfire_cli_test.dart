import 'dart:convert';
import 'dart:io';

import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:flutterfire_cli/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const firebaseProjectId = 'flutterfire-cli-test-f6f57';
  const testFileDirectory = 'test_files';
  const appleAppId = '1:262904632156:ios:58c61e319713c6142f2799';
  const androidAppId = '1:262904632156:android:eef79d5fec9aab142f2799';
  const webAppId = '1:262904632156:web:22fdf07f28e76b062f2799';

  Future<String> createFlutterProject() async {
    final tempDir = Directory.systemTemp.createTempSync();
    const flutterProject = 'flutter_test_cli';
    await Process.run(
      'flutter',
      ['create', flutterProject],
      workingDirectory: tempDir.path,
    );

    final flutterProjectPath = p.join(tempDir.path, flutterProject);

    return flutterProjectPath;
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

  String rubyScriptForCheckingBundleResourcesScript(
    String projectPath,
    String platform, {
    String runScriptName = 'flutterfire bundle-service-file',
  }) {
    final xcodeProjectPath = p.join(projectPath, platform, 'Runner.xcodeproj');
    return '''
require 'xcodeproj'
xcodeFile='$xcodeProjectPath'
runScriptName='$runScriptName'
project = Xcodeproj::Project.open(xcodeFile)


for target in project.targets 
  if (target.name == 'Runner')
    phase = target.shell_script_build_phases().find do |item|
      if defined?(item) && !item.name.nil? && item.name.is_a?(String)
        item.name.include?(runScriptName)
      end
    end

    if (phase.nil?)
      abort("failed, #{runScriptName} has not been found in build phase run scripts.")
    else
      \$stdout.write("success")
    end
  end  
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

        final testServiceFile = p.join(
          Directory.current.path,
          'test',
          testFileDirectory,
          appleServiceFileName,
        );
        // Need to find mac file like this for it to work on CI. No idea why.
        final macFile =
            await findFileInDirectory(macosPath, appleServiceFileName);

        final iosServiceFileContent = await File(iosPath).readAsString();

        final macosServiceFileContent = await macFile.readAsString();

        final testServiceFileContent =
            await File(testServiceFile).readAsString();

        expect(iosServiceFileContent, testServiceFileContent);
        expect(macosServiceFileContent, testServiceFileContent);

        // check default "firebase.json" was created and has correct content
        final firebaseJsonFile = p.join(projectPath!, 'firebase.json');
        final firebaseJsonFileContent =
            await File(firebaseJsonFile).readAsString();

        final decodedFirebaseJson =
            jsonDecode(firebaseJsonFileContent) as Map<String, dynamic>;

        // Check iOS map is correct
        final keysToMapIos = [kFlutter, kPlatforms, kIos, kDefaultConfig];
        final iosDefaultConfig =
            getNestedMap(decodedFirebaseJson, keysToMapIos);
        expect(iosDefaultConfig[kAppId], appleAppId);
        expect(iosDefaultConfig[kProjectId], firebaseProjectId);
        expect(iosDefaultConfig[kUploadDebugSymbols], false);
        expect(
          iosDefaultConfig[kFileOutput],
          '$kIos/$defaultTarget/$appleServiceFileName',
        );

        // Check macOS map is correct
        final keysToMapMacos = [kFlutter, kPlatforms, kMacos, kDefaultConfig];
        final macosDefaultConfig =
            getNestedMap(decodedFirebaseJson, keysToMapMacos);
        expect(macosDefaultConfig[kAppId], appleAppId);
        expect(macosDefaultConfig[kProjectId], firebaseProjectId);
        expect(macosDefaultConfig[kUploadDebugSymbols], false);
        expect(
          macosDefaultConfig[kFileOutput],
          '$kMacos/$defaultTarget/$appleServiceFileName',
        );

        // Check android map is correct
        final keysToMapAndroid = [
          kFlutter,
          kPlatforms,
          kAndroid,
          kDefaultConfig
        ];
        final androidDefaultConfig =
            getNestedMap(decodedFirebaseJson, keysToMapAndroid);
        expect(androidDefaultConfig[kAppId], androidAppId);
        expect(androidDefaultConfig[kProjectId], firebaseProjectId);
        expect(
          androidDefaultConfig[kFileOutput],
          'android/app/$androidServiceFileName',
        );

        // Check dart map is correct
        const defaultFilePath = 'lib/firebase_options.dart';
        final keysToMapDart = [kFlutter, kPlatforms, kDart, defaultFilePath];
        final dartConfig = getNestedMap(decodedFirebaseJson, keysToMapDart);
        expect(dartConfig[kProjectId], firebaseProjectId);
        expect(dartConfig[kFileOutput], defaultFilePath);

        final defaultConfigurations =
            dartConfig[kConfigurations] as Map<String, dynamic>;

        expect(defaultConfigurations[kIos], appleAppId);
        expect(defaultConfigurations[kMacos], appleAppId);
        expect(defaultConfigurations[kAndroid], androidAppId);
        expect(defaultConfigurations[kWeb], webAppId);

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

      final clientList = Map<String, dynamic>.from(
        jsonDecode(File(androidServiceFilePath).readAsStringSync())
            as Map<String, dynamic>,
      );

      final findClientMap =
          List<Map<String, dynamic>>.from(clientList['client'] as List<dynamic>)
              .firstWhere(
        (element) =>
            // ignore: avoid_dynamic_calls
            (element['client_info'])['mobilesdk_app_id'] == androidAppId,
      );

      expect(findClientMap, isA<Map<String, dynamic>>());

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
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

  test(
    'flutterfire configure: android - "build configuration" Apple - "build configuration"',
    () async {
      // The most basic 'flutterfire configure' command that can be run without command line prompts
      const buildType = 'development';
      const appleBuildConfiguration = 'Debug';

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

        final testServiceFile = p.join(
          Directory.current.path,
          'test',
          testFileDirectory,
          appleServiceFileName,
        );
        // Need to find mac file like this for it to work on CI. No idea why.
        final macFile =
            await findFileInDirectory(macosPath, appleServiceFileName);

        final iosServiceFileContent = await File(iosPath).readAsString();
        final macosServiceFileContent = await macFile.readAsString();

        final testServiceFileContent =
            await File(testServiceFile).readAsString();

        expect(iosServiceFileContent, testServiceFileContent);
        expect(macosServiceFileContent, testServiceFileContent);

        // check default "firebase.json" was created and has correct content
        final firebaseJsonFile = p.join(projectPath!, 'firebase.json');
        final firebaseJsonFileContent =
            await File(firebaseJsonFile).readAsString();

        final decodedFirebaseJson =
            jsonDecode(firebaseJsonFileContent) as Map<String, dynamic>;

        // Check iOS map is correct
        final keysToMapIos = [
          kFlutter,
          kPlatforms,
          kIos,
          kBuildConfiguration,
          appleBuildConfiguration,
        ];
        final iosDefaultConfig =
            getNestedMap(decodedFirebaseJson, keysToMapIos);
        expect(iosDefaultConfig[kAppId], appleAppId);
        expect(iosDefaultConfig[kProjectId], firebaseProjectId);
        expect(iosDefaultConfig[kUploadDebugSymbols], false);
        expect(
          iosDefaultConfig[kFileOutput],
          'ios/$buildType/GoogleService-Info.plist',
        );

        // Check macOS map is correct
        final keysToMapMacos = [
          kFlutter,
          kPlatforms,
          kMacos,
          kBuildConfiguration,
          appleBuildConfiguration,
        ];
        final macosDefaultConfig =
            getNestedMap(decodedFirebaseJson, keysToMapMacos);
        expect(macosDefaultConfig[kAppId], appleAppId);
        expect(macosDefaultConfig[kProjectId], firebaseProjectId);
        expect(macosDefaultConfig[kUploadDebugSymbols], false);
        expect(
          macosDefaultConfig[kFileOutput],
          'macos/$buildType/GoogleService-Info.plist',
        );

        // Check android map is correct
        final keysToMapAndroid = [
          kFlutter,
          kPlatforms,
          kAndroid,
          kBuildConfiguration,
          buildType,
        ];
        final androidDefaultConfig =
            getNestedMap(decodedFirebaseJson, keysToMapAndroid);
        expect(androidDefaultConfig[kAppId], androidAppId);
        expect(androidDefaultConfig[kProjectId], firebaseProjectId);
        expect(
          androidDefaultConfig[kFileOutput],
          'android/app/$buildType/google-services.json',
        );

        // Check dart map is correct
        const defaultFilePath = 'lib/firebase_options.dart';
        final keysToMapDart = [kFlutter, kPlatforms, kDart, defaultFilePath];
        final dartConfig = getNestedMap(decodedFirebaseJson, keysToMapDart);
        expect(dartConfig[kProjectId], firebaseProjectId);
        expect(dartConfig[kFileOutput], defaultFilePath);

        final defaultConfigurations =
            dartConfig[kConfigurations] as Map<String, dynamic>;

        expect(defaultConfigurations[kIos], appleAppId);
        expect(defaultConfigurations[kMacos], appleAppId);
        expect(defaultConfigurations[kAndroid], androidAppId);
        expect(defaultConfigurations[kWeb], webAppId);

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

      final clientList = Map<String, dynamic>.from(
        jsonDecode(File(androidServiceFilePath).readAsStringSync())
            as Map<String, dynamic>,
      );

      final findClientMap =
          List<Map<String, dynamic>>.from(clientList['client'] as List<dynamic>)
              .firstWhere(
        // ignore: avoid_dynamic_calls
        (element) => element['client_info']['mobilesdk_app_id'] == androidAppId,
      );

      expect(findClientMap, isA<Map<String, dynamic>>());

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
    timeout: const Timeout(
      Duration(minutes: 2),
    ),
  );

//   test(
//     'flutterfire configure: android - "default" Apple - "target"',
//     () async {
//       const targetType = 'Runner';
//       const applePath = 'staging/target';
//       const androidBuildConfiguration = 'development';
//       Process.runSync(
//         'flutterfire',
//         [
//           'configure',
//           '--yes',
//           '--project=$firebaseProjectId',
//           // Android just requires the `--android-out` flag to be set
//           '--android-out=android/app/$androidBuildConfiguration',
//           // Apple required the `--ios-out` and `--macos-out` flags to be set & the build type,
//           // We're using `Runner` target for both which is the standard target for an apple Flutter app
//           '--ios-out=ios/$applePath',
//           '--ios-target=$targetType',
//           '--macos-out=macos/$applePath',
//           '--macos-target=$targetType',
//           // The below args aren't needed unless running from CI. We need for Github actions to run command.
//           '--platforms=android,ios,macos,web',
//           '--ios-bundle-id=com.example.flutterTestCli',
//           '--android-package-name=com.example.flutter_test_cli',
//           '--macos-bundle-id=com.example.flutterTestCli',
//           '--web-app-id=com.example.flutterTestCli',
//         ],
//         workingDirectory: projectPath,
//       );

//       if (Platform.isMacOS) {
//         // check Apple service files were created and have correct content
//         final iosPath =
//             p.join(projectPath!, kIos, applePath, appleServiceFileName);
//         final macosPath = p.join(projectPath!, kMacos, applePath);

//         final testServiceFile = p.join(
//           Directory.current.path,
//           'test',
//           testFileDirectory,
//           appleServiceFileName,
//         );
//         // Need to find mac file like this for it to work on CI. No idea why.
//         final macFile =
//             await findFileInDirectory(macosPath, appleServiceFileName);

//         final iosServiceFileContent = await File(iosPath).readAsString();
//         final macosServiceFileContent = await macFile.readAsString();

//         final testServiceFileContent =
//             await File(testServiceFile).readAsString();

//         expect(iosServiceFileContent, testServiceFileContent);
//         expect(macosServiceFileContent, testServiceFileContent);

//         // check default "firebase.json" was created and has correct content
//         final firebaseJsonFile = p.join(projectPath!, 'firebase.json');
//         final firebaseJsonFileContent =
//             await File(firebaseJsonFile).readAsString();

//         final decodedFirebaseJson =
//             jsonDecode(firebaseJsonFileContent) as Map<String, dynamic>;

//         // Check iOS map is correct
//         final keysToMapIos = [kFlutter, kPlatforms, kIos, kTargets, targetType];
//         final iosDefaultConfig =
//             getNestedMap(decodedFirebaseJson, keysToMapIos);
//         expect(iosDefaultConfig[kAppId], appleAppId);
//         expect(iosDefaultConfig[kProjectId], firebaseProjectId);
//         expect(iosDefaultConfig[kUploadDebugSymbols], false);
//         expect(
//           iosDefaultConfig[kFileOutput],
//           'ios/$applePath/GoogleService-Info.plist',
//         );

//         // Check macOS map is correct
//         final keysToMapMacos = [
//           kFlutter,
//           kPlatforms,
//           kMacos,
//           kTargets,
//           targetType
//         ];
//         final macosDefaultConfig =
//             getNestedMap(decodedFirebaseJson, keysToMapMacos);
//         expect(macosDefaultConfig[kAppId], appleAppId);
//         expect(macosDefaultConfig[kProjectId], firebaseProjectId);
//         expect(macosDefaultConfig[kUploadDebugSymbols], false);
//         expect(
//           macosDefaultConfig[kFileOutput],
//           'macos/$applePath/GoogleService-Info.plist',
//         );

//         // Check android map is correct
//         final keysToMapAndroid = [
//           kFlutter,
//           kPlatforms,
//           kAndroid,
//           kBuildConfiguration,
//           androidBuildConfiguration,
//         ];
//         final androidDefaultConfig =
//             getNestedMap(decodedFirebaseJson, keysToMapAndroid);
//         expect(androidDefaultConfig[kAppId], androidAppId);
//         expect(androidDefaultConfig[kProjectId], firebaseProjectId);
//         expect(
//           androidDefaultConfig[kFileOutput],
//           'android/app/$androidBuildConfiguration/google-services.json',
//         );

//         // Check dart map is correct
//         const defaultFilePath = 'lib/firebase_options.dart';
//         final keysToMapDart = [kFlutter, kPlatforms, kDart, defaultFilePath];
//         final dartConfig = getNestedMap(decodedFirebaseJson, keysToMapDart);
//         expect(dartConfig[kProjectId], firebaseProjectId);
//         expect(dartConfig[kFileOutput], defaultFilePath);

//         final defaultConfigurations =
//             dartConfig[kConfigurations] as Map<String, dynamic>;

//         expect(defaultConfigurations[kIos], appleAppId);
//         expect(defaultConfigurations[kMacos], appleAppId);
//         expect(defaultConfigurations[kAndroid], androidAppId);
//         expect(defaultConfigurations[kWeb], webAppId);

//         // check GoogleService-Info.plist file is included & debug symbols script (until firebase crashlytics is a dependency) is not included in Apple "project.pbxproj" files
//         final iosXcodeProject = p.join(
//           projectPath!,
//           kIos,
//           'Runner.xcodeproj',
//         );

//         final scriptToCheckIosPbxprojFile =
//             rubyScriptForTestingDefaultConfigure(iosXcodeProject);

//         final iosResult = Process.runSync(
//           'ruby',
//           [
//             '-e',
//             scriptToCheckIosPbxprojFile,
//           ],
//         );

//         if (iosResult.exitCode != 0) {
//           fail(iosResult.stderr as String);
//         }

//         expect(iosResult.stdout, 'success');

//         final macosXcodeProject = p.join(
//           projectPath!,
//           kMacos,
//           'Runner.xcodeproj',
//         );

//         final scriptToCheckMacosPbxprojFile =
//             rubyScriptForTestingDefaultConfigure(
//           macosXcodeProject,
//         );

//         final macosResult = Process.runSync(
//           'ruby',
//           [
//             '-e',
//             scriptToCheckMacosPbxprojFile,
//           ],
//         );

//         if (macosResult.exitCode != 0) {
//           fail(macosResult.stderr as String);
//         }

//         expect(macosResult.stdout, 'success');
//       }

//       // check google-services.json was created and has correct content
//       final androidServiceFilePath = p.join(
//         projectPath!,
//         'android',
//         'app',
//         androidBuildConfiguration,
//         'google-services.json',
//       );

//       final clientList = Map<String, dynamic>.from(
//         jsonDecode(File(androidServiceFilePath).readAsStringSync())
//             as Map<String, dynamic>,
//       );

//       final findClientMap =
//           List<Map<String, dynamic>>.from(clientList['client'] as List<dynamic>)
//               .firstWhere(
//         // ignore: avoid_dynamic_calls
//         (element) => element['client_info']['mobilesdk_app_id'] == androidAppId,
//       );

//       expect(findClientMap, isA<Map<String, dynamic>>());

//       // Check android "android/build.gradle" & "android/app/build.gradle" were updated
//       const androidGradleUpdate = '''
//         // START: FlutterFire Configuration
//         classpath 'com.google.gms:google-services:4.3.10'
//         // END: FlutterFire Configuration
// ''';

//       const androidAppGradleUpdate = '''
//         // START: FlutterFire Configuration
//         apply plugin: 'com.google.gms.google-services'
//         // END: FlutterFire Configuration
//         ''';

//       final androidBuildGradle =
//           p.join(projectPath!, 'android', 'build.gradle');
//       final androidAppBuildGradle =
//           p.join(projectPath!, 'android', 'app', 'build.gradle');

//       final androidBuildGradleContent =
//           await File(androidBuildGradle).readAsString();

//       final androidAppBuildGradleContent =
//           await File(androidAppBuildGradle).readAsString();

//       expect(
//         removeWhitepaceAndNewLines(androidBuildGradleContent),
//         contains(removeWhitepaceAndNewLines(androidGradleUpdate)),
//       );
//       expect(
//         removeWhitepaceAndNewLines(androidAppBuildGradleContent),
//         contains(removeWhitepaceAndNewLines(androidAppGradleUpdate)),
//       );

//       // check "firebase_options.dart" file is created in lib directory
//       final firebaseOptions =
//           p.join(projectPath!, 'lib', 'firebase_options.dart');
//       final testFirebaseOptions = p.join(
//         Directory.current.path,
//         'test',
//         testFileDirectory,
//         'firebase_options.dart',
//       );

//       final firebaseOptionsContent = await File(firebaseOptions).readAsString();
//       final testFirebaseOptionsContent =
//           await File(testFirebaseOptions).readAsString();

//       expect(firebaseOptionsContent, testFirebaseOptionsContent);
//     },
//   );

//   test(
//     'Validate `flutterfire upload-crashlytics-symbols` script is included when `firebase_crashlytics` is a dependency',
//     () {
//       Process.runSync(
//         'flutter',
//         ['pub', 'add', 'firebase_crashlytics'],
//         workingDirectory: projectPath,
//       );

//       Process.runSync(
//         'flutterfire',
//         [
//           'configure',
//           '--yes',
//           '--project=$firebaseProjectId',
//           // The below args aren't needed unless running from CI. We need for Github actions to run command.
//           '--platforms=android,ios,macos,web',
//           '--ios-bundle-id=com.example.flutterTestCli',
//           '--android-package-name=com.example.flutter_test_cli',
//           '--macos-bundle-id=com.example.flutterTestCli',
//           '--web-app-id=com.example.flutterTestCli',
//         ],
//         workingDirectory: projectPath,
//       );
//       final iosXcodeProject = p.join(
//         projectPath!,
//         kIos,
//         'Runner.xcodeproj',
//       );

//       final scriptToCheckIosPbxprojFile =
//           rubyScriptForTestingDebugSymbolScriptExists(iosXcodeProject);

//       final iosResult = Process.runSync(
//         'ruby',
//         [
//           '-e',
//           scriptToCheckIosPbxprojFile,
//         ],
//       );

//       if (iosResult.exitCode != 0) {
//         fail(iosResult.stderr as String);
//       }

//       expect(iosResult.stdout, 'success');

//       final macosXcodeProject = p.join(
//         projectPath!,
//         kMacos,
//         'Runner.xcodeproj',
//       );

//       final scriptToCheckMacosPbxprojFile =
//           rubyScriptForTestingDebugSymbolScriptExists(
//         macosXcodeProject,
//       );

//       final macosResult = Process.runSync(
//         'ruby',
//         [
//           '-e',
//           scriptToCheckMacosPbxprojFile,
//         ],
//       );

//       if (macosResult.exitCode != 0) {
//         fail(macosResult.stderr as String);
//       }

//       expect(macosResult.stdout, 'success');
//     },
//     skip: !Platform.isMacOS,
//   );
}
