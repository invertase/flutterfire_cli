import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import '../common/utils.dart';
import '../firebase/firebase_options.dart';

const debugSymbolScriptName =
    'FlutterFire: "flutterfire upload-crashlytics-symbols"';
const bundleServiceScriptName =
    'FlutterFire: "flutterfire bundle-service-file"';

Future<FirebaseJsonWrites> appleWrites({
  required String platform,
  required String flutterAppPath,
  required String serviceFilePath,
  required FirebaseOptions platformOptions,
  required Logger logger,
  required ProjectConfiguration projectConfiguration,
  String? target,
  String? buildConfiguration,
}) {
  switch (projectConfiguration) {
    case ProjectConfiguration.buildConfiguration:
      return FirebaseAppleBuildConfiguration(
        platformOptions: platformOptions,
        flutterAppPath: flutterAppPath,
        serviceFilePath: serviceFilePath,
        logger: logger,
        platform: platform,
        projectConfiguration: projectConfiguration,
        buildConfiguration: buildConfiguration!,
      ).apply();
    case ProjectConfiguration.target:
    case ProjectConfiguration.defaultConfig:
      return FirebaseAppleTargetConfiguration(
        platformOptions: platformOptions,
        flutterAppPath: flutterAppPath,
        serviceFilePath: serviceFilePath,
        logger: logger,
        platform: platform,
        projectConfiguration: projectConfiguration,
        target: ProjectConfiguration.defaultConfig == projectConfiguration
            ? 'Runner'
            : target!,
      ).apply();
  }
}

class FirebaseAppleTargetConfiguration extends FirebaseAppleConfiguration {
  FirebaseAppleTargetConfiguration({
    required FirebaseOptions platformOptions,
    required String flutterAppPath,
    required String serviceFilePath,
    required Logger logger,
    required String platform,
    required ProjectConfiguration projectConfiguration,
    required this.target,
  }) : super(
          platformOptions: platformOptions,
          flutterAppPath: flutterAppPath,
          serviceFilePath: serviceFilePath,
          logger: logger,
          platform: platform,
          projectConfiguration: projectConfiguration,
        );

  // Default Flutter project has the target name "Runner"
  final String target;

  Future<void> _writeGoogleServiceFileToTargetProject() async {
    final addServiceFileToTargetScript = _addServiceFileToTarget();

    final resultServiceFileToTarget = await Process.run('ruby', [
      '-e',
      addServiceFileToTargetScript,
    ]);

    if (resultServiceFileToTarget.exitCode != 0) {
      throw Exception(resultServiceFileToTarget.stderr);
    }
  }

  String _addServiceFileToTarget() {
    return '''
require 'xcodeproj'
googleFile='$serviceFilePath'
xcodeFile='${getXcodeProjectPath(platform)}'
targetName='$target'

project = Xcodeproj::Project.open(xcodeFile)
target = project.targets.find { |target| target.name == targetName }

if(target)
  # Check if GoogleService-Info.plist is already in the target's resources
  serviceFileInResources = target.resources_build_phase.files.find do |file|
    if defined? file && file.file_ref && file.file_ref.path
      if file.file_ref.path.is_a? String
        file.file_ref.path.include? 'GoogleService-Info.plist'
      end
    end
  end

  # Add GoogleService-Info.plist file if it's not already in the target's resources
  if(!serviceFileInResources)
    new_file = project.new_file(googleFile)
    target.add_resources([new_file])
    project.save
  end
  
else
  abort("Could not find target: \$targetName in your Xcode workspace. Please create a target named \$targetName and try again.")
end  
''';
  }

  Future<FirebaseJsonWrites> _targetWrites() async {
    await _writeGoogleServiceFileToPath();
    await _writeGoogleServiceFileToTargetProject();

    final debugSymbolScriptAdded = await addFlutterFireDebugSymbolsScript(
      target: target,
      flutterAppPath: flutterAppPath,
      logger: logger,
      platform: platform,
      projectConfiguration: projectConfiguration,
    );

    return _firebaseJsonWrites(debugSymbolScriptAdded, target);
  }

  @override
  Future<FirebaseJsonWrites> apply() {
    return _targetWrites();
  }
}

class FirebaseAppleBuildConfiguration extends FirebaseAppleConfiguration {
  FirebaseAppleBuildConfiguration({
    required FirebaseOptions platformOptions,
    required String flutterAppPath,
    required String serviceFilePath,
    required Logger logger,
    required String platform,
    required ProjectConfiguration projectConfiguration,
    required this.buildConfiguration,
  }) : super(
          platformOptions: platformOptions,
          flutterAppPath: flutterAppPath,
          serviceFilePath: serviceFilePath,
          logger: logger,
          platform: platform,
          projectConfiguration: projectConfiguration,
        );
  // e.g. Debug, Profile, Release, etc
  final String buildConfiguration;

  Future<void> _writeBundleServiceFileScriptToProject() async {
    final addBuildPhaseScript = _bundleServiceFileScript();

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
  }

  String _bundleServiceFileScript() {
    String? command;
    if (platform == kMacos) {
      // macOS is bundled in Contents/Resources directory
      command =
          '# Define the Resources directory path\nRESOURCES_DIR=\${BUILT_PRODUCTS_DIR}/\${PRODUCT_NAME}.app/Contents/Resources\n\n# Create the Resources directory if it does not exist\n mkdir -p "\$RESOURCES_DIR"\n\n flutterfire bundle-service-file --plist-destination="\$RESOURCES_DIR" --build-configuration=\${CONFIGURATION} --platform=$platform --apple-project-path=\${SRCROOT}';
    } else {
      // iOS is bundled in the root of the app bundle
      command =
          'flutterfire bundle-service-file --plist-destination=\${BUILT_PRODUCTS_DIR}/\${PRODUCT_NAME}.app --build-configuration=\${CONFIGURATION} --platform=$platform --apple-project-path=\${SRCROOT}';
    }

    return '''
require 'xcodeproj'
xcodeFile='${getXcodeProjectPath(platform)}'
runScriptName='$bundleServiceScriptName'
project = Xcodeproj::Project.open(xcodeFile)


# multi line argument for bash script
bashScript = %q(
#!/bin/bash
PATH=\${PATH}:\$FLUTTER_ROOT/bin:\$HOME/.pub-cache/bin
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

  Future<FirebaseJsonWrites> _buildConfigurationWrites() async {
    await _writeGoogleServiceFileToPath();
    await _writeBundleServiceFileScriptToProject();
    final debugSymbolScriptAdded = await addFlutterFireDebugSymbolsScript(
      flutterAppPath: flutterAppPath,
      logger: logger,
      projectConfiguration: projectConfiguration,
      platform: platform,
    );

    return _firebaseJsonWrites(
      debugSymbolScriptAdded,
      buildConfiguration,
    );
  }

  @override
  Future<FirebaseJsonWrites> apply() {
    return _buildConfigurationWrites();
  }
}

// Use for both macOS & iOS
abstract class FirebaseAppleConfiguration {
  FirebaseAppleConfiguration({
    required this.platformOptions,
    required this.flutterAppPath,
    required this.serviceFilePath,
    required this.logger,
    required this.platform,
    required this.projectConfiguration,
  });
  // Either "ios" or "macos"
  final String platform;
  final String flutterAppPath;
  final FirebaseOptions platformOptions;
  final String serviceFilePath;
  final Logger logger;
  ProjectConfiguration projectConfiguration;

  FirebaseJsonWrites _firebaseJsonWrites(
    bool uploadDebugSymbols,
    // name of build configuration or target
    String name,
  ) {
    // "buildConfiguration", "targets" or "default" property
    final configuration = getProjectConfigurationProperty(projectConfiguration);
    final keysToMap = [kFlutter, kPlatforms, platform, configuration];

    if (ProjectConfiguration.defaultConfig != projectConfiguration) {
      // "buildConfiguration" or "targets" name if the map is not default config
      keysToMap.add(name);
    }

    return FirebaseJsonWrites(
      pathToMap: keysToMap,
      projectId: platformOptions.projectId,
      appId: platformOptions.appId,
      fileOutput: path.relative(serviceFilePath, from: flutterAppPath),
      uploadDebugSymbols: uploadDebugSymbols,
    );
  }

  Future<File> _createServiceFileToSpecifiedPath() async {
    await Directory(path.dirname(serviceFilePath)).create(recursive: true);

    return File(serviceFilePath);
  }

  Future<void> _writeGoogleServiceFileToPath() async {
    final file = await _createServiceFileToSpecifiedPath();

    await file.writeAsString(platformOptions.optionsSourceContent);
  }

  Future<FirebaseJsonWrites> apply();
}

Future<bool> addFlutterFireDebugSymbolsScript({
  String target = 'Runner',
  required String flutterAppPath,
  required Logger logger,
  required String platform,
  required ProjectConfiguration projectConfiguration,
}) async {
  final packageConfigContents = File(
    path.join(
      flutterAppPath,
      '.dart_tool',
      'package_config.json',
    ),
  );

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
    final pubspecContents = await File(
      path.join(
        flutterAppPath,
        'pubspec.yaml',
      ),
    ).readAsString();

    final yamlContents = loadYaml(pubspecContents) as Map;

    crashlyticsDependencyExists = yamlContents['dependencies'] != null &&
        (yamlContents['dependencies'] as Map)
            .containsKey(crashlyticsDependency);
  }

  if (crashlyticsDependencyExists) {
    // Add the debug script

    final debugSymbolScript = await Process.run('ruby', [
      '-e',
      _debugSymbolsScript(
        target,
        projectConfiguration,
        platform,
      ),
    ]);

    if (debugSymbolScript.exitCode != 0) {
      throw Exception(debugSymbolScript.stderr);
    }

    if (debugSymbolScript.stdout != null) {
      logger.stdout(debugSymbolScript.stdout as String);
    }
    return true;
  }
  return false;
}

String _debugSymbolsScript(
  // Always "Runner" for "build configuration" setup
  String target,
  ProjectConfiguration projectConfiguration,
  String platform,
) {
  var command =
      'flutterfire upload-crashlytics-symbols --upload-symbols-script-path=\$PODS_ROOT/FirebaseCrashlytics/upload-symbols --platform=$platform --apple-project-path=\${SRCROOT} --env-platform-name=\${PLATFORM_NAME} --env-configuration=\${CONFIGURATION} --env-project-dir=\${PROJECT_DIR} --env-built-products-dir=\${BUILT_PRODUCTS_DIR} --env-dwarf-dsym-folder-path=\${DWARF_DSYM_FOLDER_PATH} --env-dwarf-dsym-file-name=\${DWARF_DSYM_FILE_NAME} --env-infoplist-path=\${INFOPLIST_PATH} ';

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
PATH=\${PATH}:\$FLUTTER_ROOT/bin:\$HOME/.pub-cache/bin
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
