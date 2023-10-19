import 'package:path/path.dart' as path;

import '../strings.dart';
import '../utils.dart';

String getAppleServiceFile(
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
