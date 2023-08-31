import 'dart:io';

import 'package:path/path.dart' as path;

import './prompts/android_prompts.dart';
import './prompts/apple_prompts.dart';
import './prompts/dart_file_prompts.dart';
import 'inputs.dart';
import 'strings.dart';
import 'utils.dart';

Future<AppleInputs> appleValidation({
  required String platform,
  required String flutterAppPath,
  String? target,
  String? buildConfiguration,
  String? serviceFilePath,
}) async {
  String? targetResponse;
  String? buildConfigurationResponse;
  var configurationResponse = ProjectConfiguration.defaultConfig;

  if (target == null && buildConfiguration == null && serviceFilePath == null) {
    // Default configuration
    return AppleInputs(
      projectConfiguration: configurationResponse,
      target: 'Runner',
      serviceFilePath: path.join(
        Directory.current.path,
        platform,
        'Runner',
        appleServiceFileName,
      ),
    );
  }

  if (buildConfiguration != null && target != null) {
    // If user has set both, we need to find out which one they want to use
    final response = promptSelect(
      'You have both a build configuration (most likely choice) and a target set up. Which would you like to use?',
      [
        'Build configuration. You chose: $buildConfiguration',
        'Target. You chose: $target',
      ],
    );

    configurationResponse = response == 0
        ? ProjectConfiguration.buildConfiguration
        : ProjectConfiguration.target;
  }

  if (serviceFilePath != null && target == null && buildConfiguration == null) {
    // If user has set serviceFilePath, but not a config type, we need to find out which one they want to use
    final response = promptSelect(
      'You have to choose a configuration type. Either build configuration (most likely choice) or a target set up.',
      [
        'Build configuration',
        'Target',
      ],
    );

    configurationResponse = response == 0
        ? ProjectConfiguration.buildConfiguration
        : ProjectConfiguration.target;

    if (configurationResponse == ProjectConfiguration.target) {
      // User chooses from list of targets
      targetResponse = await promptGetTarget(platform);
    }

    if (configurationResponse == ProjectConfiguration.buildConfiguration) {
      // User chooses from list of build configurations
      buildConfigurationResponse = await promptGetBuildConfiguration(platform);
    }
  }

  if (serviceFilePath != null && target != null) {
    // Check if target exists
    targetResponse = await promptCheckTarget(target, platform);
    configurationResponse = ProjectConfiguration.target;
  }

  if (serviceFilePath != null && buildConfiguration != null) {
    // Check if build configuration exists
    buildConfigurationResponse = await promptCheckBuildConfiguration(
      buildConfiguration,
      platform,
    );
    configurationResponse = ProjectConfiguration.buildConfiguration;
  }

  return AppleInputs(
    projectConfiguration: configurationResponse,
    buildConfiguration: buildConfigurationResponse,
    target: targetResponse,
    serviceFilePath: getAppleServiceFile(
      serviceFilePath,
      platform,
      flutterAppPath,
    ),
  );
}

AndroidInputs androidValidation({
  String? serviceFilePath,
  required String flutterAppPath,
}) {
  if (serviceFilePath == null) {
    return AndroidInputs(
      projectConfiguration: ProjectConfiguration.defaultConfig,
    );
  }

  final validatedServiceFilePath = getAndroidServiceFile(
    serviceFilePath: serviceFilePath,
    flutterAppPath: flutterAppPath,
  );

  return AndroidInputs(
    serviceFilePath: validatedServiceFilePath,
    projectConfiguration: ProjectConfiguration.buildConfiguration,
  );
}

DartConfigurationFileInputs dartConfigurationFileValidation({
  required String configurationFilePath,
  required String flutterAppPath,
  required bool overwrite,
}) {
  final validatedConfigurationFilePath = getFirebaseConfigurationFile(
    configurationFilePath: configurationFilePath,
    flutterAppPath: flutterAppPath,
  );
  final writeConfigurationFile = overwrite ||
      promptWriteConfigurationFile(
        configurationFilePath: validatedConfigurationFilePath,
      );

  return DartConfigurationFileInputs(
    configurationFilePath: validatedConfigurationFilePath,
    writeConfigurationFile: writeConfigurationFile,
  );
}
