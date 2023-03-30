import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import '../common/strings.dart';
import '../common/utils.dart';
import '../firebase/firebase_options.dart';

import '../flutter_app.dart';

// Use for both macOS & iOS
class FirebaseAppleSetup {
  FirebaseAppleSetup({
    required this.platformOptions,
    required this.flutterAppPath,
    required this.serviceFilePath,
    required this.logger,
    this.buildConfiguration,
    this.target,
    required this.platform,
    required this.projectConfiguration,
    // We have asserts because validation is the very first thing to happen before any API requests/writes are made. This is a helper for developers.
  })  : assert(target != null && buildConfiguration != null, validationCheck),
        assert(
          projectConfiguration == ProjectConfiguration.target && target == null,
          validationCheck,
        ),
        assert(
          projectConfiguration == ProjectConfiguration.buildConfiguration &&
              buildConfiguration == null,
          validationCheck,
        );
  // Either "ios" or "macos"
  final String platform;
  final String flutterAppPath;
  final FirebaseOptions platformOptions;
  final String serviceFilePath;
  final Logger logger;
  String? buildConfiguration;
  String? target;
  ProjectConfiguration projectConfiguration;

  Future<bool> _addFlutterFireDebugSymbolsScript(
    Logger logger,
    ProjectConfiguration projectConfiguration, {
    String target = 'Runner',
  }) async {
    final packageConfigContents =
        File('$flutterAppPath/.dart_tool/package_config.json');

    var crashlyticsDependencyExists = false;
    const crashlyticsDependency = 'firebase_crashlytics';

    if (packageConfigContents.existsSync()) {
      final decodePackageConfig = await packageConfigContents.readAsString();

      final packageConfig = jsonDecode(decodePackageConfig) as Map;

      final packages = packageConfig['packages'] as List<dynamic>;
      crashlyticsDependencyExists = packages.any(
        (dynamic package) =>
            package is Map && package['name'] == crashlyticsDependency,
      );
    } else {
      final pubspecContents =
          await File('$flutterAppPath/pubspec.yaml').readAsString();

      final yamlContents = loadYaml(pubspecContents) as Map;

      crashlyticsDependencyExists = yamlContents['dependencies'] != null &&
          (yamlContents['dependencies'] as Map)
              .containsKey(crashlyticsDependency);
    }

    if (crashlyticsDependencyExists) {
      // Add the debug script
      final paths = _addPathToExecutablesForBuildPhaseScripts();
      if (paths != null) {
        final debugSymbolScript = await Process.run('ruby', [
          '-e',
          _debugSymbolsScript(
            target,
            paths,
            projectConfiguration,
          ),
        ]);

        if (debugSymbolScript.exitCode != 0) {
          throw Exception(debugSymbolScript.stderr);
        }

        if (debugSymbolScript.stdout != null) {
          logger.stdout(debugSymbolScript.stdout as String);
        }
        return true;
      } else {
        logger.stdout(
          noPathsToExecutables,
        );
      }
    }
    return false;
  }

  String _debugSymbolsScript(
    // Always "Runner" for "build configuration" setup
    String target,
    String pathsToExecutables,
    ProjectConfiguration projectConfiguration,
  ) {
    var command =
        'flutterfire upload-crashlytics-symbols --upload-symbols-script-path=\$PODS_ROOT/FirebaseCrashlytics/upload-symbols --debug-symbols-path=\${DWARF_DSYM_FOLDER_PATH}/\${DWARF_DSYM_FILE_NAME} --info-plist-path=\${SRCROOT}/\${BUILT_PRODUCTS_DIR}/\${INFOPLIST_PATH} --platform=${platform} --apple-project-path=\${SRCROOT} ';

    switch (projectConfiguration) {
      case ProjectConfiguration.buildConfiguration:
        command += r'--build-configuration=${CONFIGURATION}';
        break;
      case ProjectConfiguration.target:
        command += '--target=$target';
        break;
      case ProjectConfiguration.defaultConfig:
        command += '--default-config=default';
    }

    return '''
require 'xcodeproj'
xcodeFile='${getXcodeProjectPath(platform)}'
runScriptName='$debugSymbolScriptName'
project = Xcodeproj::Project.open(xcodeFile)


# multi line argument for bash script
bashScript = %q(
#!/bin/bash
PATH=\${PATH}:$pathsToExecutables
$command
)

for target in project.targets 
  if (target.name == '$target')
    phase = target.shell_script_build_phases().find do |item|
      if defined? item && item.name
        item.name == runScriptName
      end
    end

    if (!phase.nil?)
      phase.remove_from_project()
    end
    
    phase = target.new_shell_script_build_phase(runScriptName)
    phase.shell_script = bashScript
    project.save()   
  end  
end
''';
  }

  String _bundleServiceFileScript(String pathsToExecutables) {
    final command =
        'flutterfire bundle-service-file --plist-destination=\${BUILT_PRODUCTS_DIR}/\${PRODUCT_NAME}.app --build-configuration=\${CONFIGURATION} --platform=${platform} --apple-project-path=\${SRCROOT}';

    return '''
require 'xcodeproj'
xcodeFile='${getXcodeProjectPath(platform)}'
runScriptName='$bundleServiceScriptName'
project = Xcodeproj::Project.open(xcodeFile)


# multi line argument for bash script
bashScript = %q(
#!/bin/bash
PATH=\${PATH}:$pathsToExecutables
$command
)

for target in project.targets 
  if (target.name == 'Runner')
    phase = target.shell_script_build_phases().find do |item|
      if defined? item && item.name
        item.name == runScriptName
      end
    end

    if (!phase.nil?)
      phase.remove_from_project()
    end
    
    phase = target.new_shell_script_build_phase(runScriptName)
    phase.shell_script = bashScript
    project.save()   
  end  
end
    ''';
  }

  final debugSymbolScriptName =
      'FlutterFire: "flutterfire upload-crashlytics-symbols"';
  final bundleServiceScriptName =
      'FlutterFire: "flutterfire bundle-service-file"';

  Future<void> _updateFirebaseJsonFile(
    String appId,
    String projectId,
    bool debugSymbolScript,
    String targetOrBuildConfiguration,
    String pathToServiceFile,
    ProjectConfiguration projectConfiguration,
  ) async {
    final file = File(path.join(flutterAppPath, 'firebase.json'));

    final relativePathFromProject =
        path.relative(pathToServiceFile, from: flutterAppPath);

    // "buildConfiguration", "targets" or "default" property
    final configuration = getProjectConfigurationProperty(projectConfiguration);

    final fileAsString = await file.readAsString();

    final map = jsonDecode(fileAsString) as Map;

    final flutterConfig = map[kFlutter] as Map;
    final platforms = flutterConfig[kPlatforms] as Map;

    final platformKey = platform == kIos ? kIos : kMacos;

    if (platforms[platformKey] == null) {
      platforms[platformKey] = <String, Object>{};
    }
    final appleConfig = platforms[platformKey] as Map;

    if (appleConfig[configuration] == null) {
      appleConfig[configuration] = <String, Object>{};
    }
    final configurationMaps = appleConfig[configuration] as Map?;

    Map? configurationMap;
    // For "build configuration" or "target" we need to create a nested map if it does not exist
    if (ProjectConfiguration.target == projectConfiguration ||
        ProjectConfiguration.buildConfiguration == projectConfiguration) {
      if (configurationMaps?[targetOrBuildConfiguration] == null) {
        // ignore: implicit_dynamic_map_literal
        configurationMaps?[targetOrBuildConfiguration] = {};
      }
      configurationMap = configurationMaps?[targetOrBuildConfiguration] as Map;
    } else {
      // Only a single map in "default" configuration.
      configurationMap = configurationMaps;
    }

    configurationMap?[kProjectId] = projectId;
    configurationMap?[kAppId] = appId;
    configurationMap?[kUploadDebugSymbols] = debugSymbolScript;
    configurationMap?[kServiceFileOutput] = relativePathFromProject;

    final mapJson = json.encode(map);

    file.writeAsStringSync(mapJson);
  }

  Future<void> _updateFirebaseJsonAndDebugSymbolScript(
    String pathToServiceFile,
    ProjectConfiguration projectConfiguration,
    String targetOrBuildConfiguration,
  ) async {
    final debugSymbolScriptAdded = await _addFlutterFireDebugSymbolsScript(
      logger,
      projectConfiguration,
      target: targetOrBuildConfiguration,
    );

    await _updateFirebaseJsonFile(
      platformOptions.appId,
      platformOptions.projectId,
      debugSymbolScriptAdded,
      targetOrBuildConfiguration,
      pathToServiceFile,
      projectConfiguration,
    );
  }

  String? _addPathToExecutablesForBuildPhaseScripts() {
    final envVars = Platform.environment;
    final paths = envVars['PATH'];
    if (paths != null) {
      final array = paths.split(':');
      // Need to add paths to PATH variable in Xcode environment to execute FlutterFire & Dart executables.
      // The resulting output will be paths specific to your machine. Here is how it might look in the Build Phase script in Xcode:
      // e.g. PATH=${PATH}:/Users/yourname/sdks/flutter/bin/cache/dart-sdk/bin:/Users/yourname/sdks/flutter/bin:/Users/yourname/.pub-cache/bin
      // This script is replaced every time you call `flutterfire configure` so the path variable is always specific to the machine
      // This does work on the presumption that you have the Dart & FlutterFire CLI (in .pub-cache/ directory) on your path on your machine setup
      final pathsToAddToScript = array.where((path) {
        if (path.contains('dart-sdk') ||
            path.contains('flutter') ||
            path.contains('.pub-cache')) {
          return true;
        }
        return false;
      });

      return pathsToAddToScript.join(':');
    } else {
      logger.stdout(
        noPathVariableFound,
      );
      return null;
    }
  }

  String _addServiceFileToTarget(
    String googleServiceInfoFile,
    String targetName,
  ) {
    return '''
require 'xcodeproj'
googleFile='$googleServiceInfoFile'
xcodeFile='${getXcodeProjectPath(platform)}'
targetName='$targetName'

project = Xcodeproj::Project.open(xcodeFile)

file = project.new_file(googleFile)
target = project.targets.find { |target| target.name == targetName }

if(target)
  exists = target.resources_build_phase.files.find do |file|
    if defined? file && file.file_ref && file.file_ref.path
      if file.file_ref.path.is_a? String
        file.file_ref.path.include? 'GoogleService-Info.plist'
      end
    end
  end  
  if !exists
    target.add_resources([file])
    project.save
  end
else
  abort("Could not find target: \$targetName in your Xcode workspace. Please create a target named \$targetName and try again.")
end  
''';
  }

  Future<void> _writeGoogleServiceFileToTargetProject(
    String serviceFilePath,
    String target,
  ) async {
    final addServiceFileToTargetScript = _addServiceFileToTarget(
      serviceFilePath,
      target,
    );

    final resultServiceFileToTarget = await Process.run('ruby', [
      '-e',
      addServiceFileToTargetScript,
    ]);

    if (resultServiceFileToTarget.exitCode != 0) {
      throw Exception(resultServiceFileToTarget.stderr);
    }
  }

  Future<File> _createServiceFileToSpecifiedPath(
    String pathToServiceFile,
  ) async {
    await Directory(path.dirname(pathToServiceFile)).create(recursive: true);

    return File(pathToServiceFile);
  }

  Future<void> _writeGoogleServiceFileToPath(String pathToServiceFile) async {
    final file = await _createServiceFileToSpecifiedPath(pathToServiceFile);

    if (!file.existsSync()) {
      await file.writeAsString(platformOptions.optionsSourceContent);
    } else {
      logger.stdout(serviceFileAlreadyExists);
    }
  }

  Future<void> _writeBundleServiceFileScriptToProject(
    String serviceFilePath,
    String buildConfiguration,
    Logger logger,
  ) async {
    final paths = _addPathToExecutablesForBuildPhaseScripts();
    if (paths != null) {
      final addBuildPhaseScript = _bundleServiceFileScript(paths);

      // Add "bundle-service-file" script to Build Phases in Xcode project
      final resultBuildPhase = await Process.run('ruby', [
        '-e',
        addBuildPhaseScript,
      ]);

      if (resultBuildPhase.exitCode != 0) {
        throw Exception(resultBuildPhase.stderr);
      }

      if (resultBuildPhase.stdout != null) {
        logger.stdout(resultBuildPhase.stdout as String);
      }
    } else {
      logger.stdout(
        noPathsToExecutables,
      );
    }
  }

  Future<void> _buildConfigurationWrites() async {
    await _writeGoogleServiceFileToPath(serviceFilePath!);
    await _writeBundleServiceFileScriptToProject(
      serviceFilePath,
      buildConfiguration!,
      logger,
    );
    await _updateFirebaseJsonAndDebugSymbolScript(
      serviceFilePath,
      ProjectConfiguration.buildConfiguration,
      buildConfiguration!,
    );
  }

  Future<void> _targetWrites({
    ProjectConfiguration projectConfiguration = ProjectConfiguration.target,
  }) async {
    await _writeGoogleServiceFileToPath(serviceFilePath!);
    await _writeGoogleServiceFileToTargetProject(
      serviceFilePath,
      target!,
    );

    await _updateFirebaseJsonAndDebugSymbolScript(
      serviceFilePath,
      projectConfiguration,
      target!,
    );
  }

  Future<void> apply() async {
    switch (projectConfiguration) {
      case ProjectConfiguration.target:
        await _targetWrites();
        break;
      case ProjectConfiguration.buildConfiguration:
        await _buildConfigurationWrites();
        break;
      case ProjectConfiguration.defaultConfig:
        await _targetWrites(
          projectConfiguration: ProjectConfiguration.defaultConfig,
        );
        break;
    }
  }
}
