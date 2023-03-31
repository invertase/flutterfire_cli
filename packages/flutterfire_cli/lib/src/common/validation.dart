import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:path/path.dart' as path;

import 'strings.dart';
import 'utils.dart';

class AppleInputs {
  AppleInputs({
    this.buildConfiguration,
    this.target,
    required this.serviceFilePath,
    required this.projectConfiguration,
  });
  final String? buildConfiguration;
  final String? target;
  final String serviceFilePath;
  ProjectConfiguration projectConfiguration;
}

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
    serviceFilePath: _getAppleServiceFile(
      serviceFilePath,
      platform,
      flutterAppPath,
    ),
  );
}

String _getAppleServiceFile(
  String? serviceFilePath,
  String platform,
  String flutterAppPath,
) {
  if (serviceFilePath == null) {
    return promptAppleServiceFilePath(
      platform: platform,
      flag: platform == kIos ? kIosOutFlag : kMacosOutFlag,
      flutterAppPath: flutterAppPath,
    );
  }

  final fileName = path.basename(serviceFilePath);

  if (fileName == appleServiceFileName) {
    return path.join(
      flutterAppPath,
      removeForwardBackwardSlash(serviceFilePath),
    );
  }

  if (fileName.contains('.')) {
    return promptAppleServiceFilePath(
      platform: platform,
      flag: platform == kIos ? kIosOutFlag : kMacosOutFlag,
      flutterAppPath: flutterAppPath,
    );
  }

  return path.join(
    flutterAppPath,
    removeForwardBackwardSlash(serviceFilePath),
    appleServiceFileName,
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

String promptAppleServiceFilePath({
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

class AndroidInputs {
  AndroidInputs({
    this.serviceFilePath,
    required this.projectConfiguration,
  });
  final String? serviceFilePath;
  ProjectConfiguration projectConfiguration;
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

  final validatedServiceFilePath = _getAndroidServiceFile(
    serviceFilePath: serviceFilePath,
    flutterAppPath: flutterAppPath,
  );

  return AndroidInputs(
    serviceFilePath: validatedServiceFilePath,
    projectConfiguration: ProjectConfiguration.buildConfiguration,
  );
}

String _getAndroidServiceFile({
  required String serviceFilePath,
  required String flutterAppPath,
}) {
  final segments = removeForwardBackwardSlash(serviceFilePath).split('/');
  // Path should have the signature:
  // android/app/google-services.json
  // android/app/development
  // android/app
  if (segments[0] == 'android' &&
      segments[1] == 'app' &&
      (segments.last == androidServiceFileName ||
          !segments.last.contains('.'))) {
    if (segments.last == androidServiceFileName) {
      return path.join(
        flutterAppPath,
        removeForwardBackwardSlash(serviceFilePath),
      );
    } else {
      return path.join(
        flutterAppPath,
        removeForwardBackwardSlash(serviceFilePath),
        androidServiceFileName,
      );
    }
  } else {
    // Prompt for service file path
    final serviceFilePath = promptInput(
      'Enter a path for your android "$androidServiceFileName" file ("$kAndroidOutFlag" flag.) relative to the root of your Flutter project. Example input: android/app/staging/$androidServiceFileName',
      validator: (String x) {
        final segments = removeForwardBackwardSlash(x).split('/');

        if (segments[0] == 'android' && segments[1] == 'app') {
          final last = segments.last;

          if (!last.contains('.')) {
            // Just path, no file name
            return true;
          } else {
            if (last == androidServiceFileName) {
              return true;
            } else {
              return 'The file name must be "$androidServiceFileName"';
            }
          }
        } else {
          return 'The path must start with `android/app`. See documentation for more information: https://firebase.google.com/docs/projects/multiprojects';
        }
      },
    );

    if (path.basename(serviceFilePath) == androidServiceFileName) {
      return path.join(
        flutterAppPath,
        removeForwardBackwardSlash(serviceFilePath),
      );
    } else {
      return path.join(
        flutterAppPath,
        removeForwardBackwardSlash(serviceFilePath),
        androidServiceFileName,
      );
    }
  }
}

class FirebaseConfigurationFileInputs {
  FirebaseConfigurationFileInputs({
    required this.configurationFilePath,
    required this.writeConfigurationFile,
  });
  final String configurationFilePath;
  final bool writeConfigurationFile;
}

FirebaseConfigurationFileInputs firebaseConfigurationFileValidation({
  String? configurationFilePath,
  required String flutterAppPath,
}) {
  final validatedConfigurationFilePath = configurationFilePath == null
      // Default service file path
      ? path.join(flutterAppPath, 'lib', 'firebase_options.dart')
      : _getFirebaseConfigurationFile(
          configurationFilePath: configurationFilePath,
          flutterAppPath: flutterAppPath,
        );
  final writeConfigurationFile = _promptWriteConfigurationFile(
    configurationFilePath: validatedConfigurationFilePath,
  );

  return FirebaseConfigurationFileInputs(
    configurationFilePath: validatedConfigurationFilePath,
    writeConfigurationFile: writeConfigurationFile,
  );
}

String _getFirebaseConfigurationFile({
  required String configurationFilePath,
  required String flutterAppPath,
}) {
  final segments = removeForwardBackwardSlash(configurationFilePath).split('/');

  if (segments.last.contains('.dart')) {
    return path.join(
      flutterAppPath,
      removeForwardBackwardSlash(configurationFilePath),
    );
  } else {
    final configurationFilePath = promptInput(
      'Enter a path for your FirebaseOptions file. It must be to a dart file. Example input: lib/firebase_options.dart',
      validator: (String x) {
        final segments = removeForwardBackwardSlash(x).split('/');

        if (segments.last.contains('.dart')) {
          return true;
        } else {
          return 'The path must be to a dart file. Example input: lib/firebase_options.dart';
        }
      },
    );

    return path.join(
      flutterAppPath,
      removeForwardBackwardSlash(configurationFilePath),
    );
  }
}

bool _promptWriteConfigurationFile({
  required String configurationFilePath,
}) {
  final outputFile = File(configurationFilePath);
  final fileExists = outputFile.existsSync();

  if (!fileExists || isCI) {
    return true;
  } else {
    final shouldOverwrite = promptBool(
      'Generated FirebaseOptions file ${AnsiStyles.cyan(configurationFilePath)} already exists, do you want to override it?',
    );

    return shouldOverwrite;
  }
}