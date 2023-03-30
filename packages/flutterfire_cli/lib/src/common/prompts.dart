import 'package:path/path.dart' as path;

import 'package:flutterfire_cli/src/common/strings.dart';
import 'package:flutterfire_cli/src/common/utils.dart';

class AppleResponses {
  AppleResponses({
    this.buildConfiguration,
    this.target,
    this.serviceFilePath,
    required this.configuration,
  });
  final String? buildConfiguration;
  final String? target;
  final String? serviceFilePath;
  ProjectConfiguration configuration;
}

Future<AppleResponses> applePrompts({
  required String platform,
  required String flutterAppPath,
  String? target,
  String? buildConfiguration,
  String? serviceFilePath,
}) async {
  String? serviceFilePathResponse;
  String? targetResponse;
  String? buildConfigurationResponse;
  var configurationResponse = ProjectConfiguration.defaultConfig;

  if (target == null && buildConfiguration == null && serviceFilePath == null) {
    // Default configuration
    return AppleResponses(
      configuration: configurationResponse,
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

  if (serviceFilePath == null) {
    // Gets service file path for both target and build configuration
    serviceFilePathResponse = promptServiceFilePath(
      platform: platform,
      flag: platform == kIos ? kIosOutFlag : kMacosOutFlag,
      flutterAppPath: flutterAppPath,
    );
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
    buildConfigurationResponse = await promptCheckBuildConfiguration(
      buildConfiguration,
      platform,
    );
    configurationResponse = ProjectConfiguration.buildConfiguration;
  }

  return AppleResponses(
    configuration: configurationResponse,
    buildConfiguration: buildConfigurationResponse,
    target: targetResponse,
    serviceFilePath: serviceFilePathResponse,
  );
}

Future<String> promptCheckBuildConfiguration(
  String buildConfiguration,
  String platform,
) async {
  final buildConfigurations = await findBuildConfigurationsAvailable(
    platform,
    getXcodeProjectPath(platform),
  );

  if (!buildConfigurations.contains(buildConfiguration)) {
    final response = promptSelect(
      'You have chosen a buildConfiguration that does not exist: $buildConfiguration. Please choose one of the following build configurations',
      buildConfigurations,
    );

    return buildConfigurations[response];
  }
  return buildConfiguration;
}

Future<String> promptGetBuildConfiguration(String platform) async {
  final buildConfigurations = await findBuildConfigurationsAvailable(
    platform,
    getXcodeProjectPath(platform),
  );

  final response = promptSelect(
    'Please choose one of the following build configurations',
    buildConfigurations,
  );

  return buildConfigurations[response];
}

Future<String> promptGetTarget(String platform) async {
  final targets =
      await findTargetsAvailable(platform, getXcodeProjectPath(platform));

  final response = promptSelect(
    'Please choose one of the following targets',
    targets,
  );

  return targets[response];
}

Future<String> promptCheckTarget(String target, String platform) async {
  final targets =
      await findTargetsAvailable(platform, getXcodeProjectPath(platform));

  if (!targets.contains(target)) {
    final response = promptSelect(
      'You have chosen a target that does not exist: $target. Please choose one of the following targets',
      targets,
    );

    return targets[response];
  }

  return target;
}

String promptServiceFilePath({
  required String platform,
  required String flag,
  required String flutterAppPath,
}) {
  final serviceFilePath = promptInput(
    'Enter a path for your $platform "$appleServiceFileName" ("$flag" flag.) relative to the root of your Flutter project. Example input: $platform/dev',
    validator: (String x) {
      final basename = path.basename(x);
      if (basename == appleServiceFileName) {
        return true;
      } else if (basename.contains('.')) {
        return 'The file name must be "$appleServiceFileName"';
      }

      return true;
    },
  );

  final fileName = path.basename(serviceFilePath);

  if (fileName == appleServiceFileName) {
    return path.join(
      flutterAppPath,
      removeForwardBackwardSlash(serviceFilePath),
    );
  } else {
    return path.join(
      flutterAppPath,
      removeForwardBackwardSlash(serviceFilePath),
      appleServiceFileName,
    );
  }
}