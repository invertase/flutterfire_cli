import 'dart:io';

import 'package:path/path.dart' as path;

import 'strings.dart';
import 'utils.dart';


// Apple validation functions
Future<void> validateAppleInputs({
  String? buildConfiguration,
  String? target,
  String? serviceFilePath,
  required String flutterAppPath,
  String? platform = kIos,
  String? appleTargetFlag = kIosTargetFlag,
  String? appleBuildConfigFlag = kIosBuildConfigFlag,
  String serviceFilePathFlag = kIosOutFlag,
}) async {
  final validatedServiceFilePath = _appleServiceFileValidation(serviceFilePath, platform!, flutterAppPath);
  // Cannot have build configuration and target setup at the same time.
  if (buildConfiguration != null && target != null) {
    throw XcodeProjectException(
      platform,
      'XcodeProjectException: choose either a `${appleTargetFlag!}` or a `${appleBuildConfigFlag!}` for your $platform project setup',
    );
  }

  // Need to specify a path to service file for target or build configuration.
  if ((target != null || buildConfiguration != null) &&
      validatedServiceFilePath == null) {
    throw ServiceFileException(
      platform,
      'Please specify a path to your $appleServiceFileName service file using the `$serviceFilePathFlag` flag.',
    );
  }

  // Need to specify a target or build configuration if you have specified a path to service file.
  if ((target == null && buildConfiguration == null) &&
      validatedServiceFilePath != null) {
    throw XcodeProjectException(
      platform,
      'Please specify a target using the `${appleTargetFlag!}` flag OR a build configuration with the `${appleBuildConfigFlag!}` flag.',
    );
  }

  final xcodeProjectPath = getXcodeProjectPath(platform);

  // Check if target exists in Xcode project.
  if (target != null) {
    final targets = await findTargetsAvailable(platform, xcodeProjectPath);
    if (!targets.contains(target)) {
      throw XcodeProjectException(
        platform,
        'XcodeProjectException: the target "$target" does not exist in your Xcode workspace. Please choose one of the following targets: ${targets.join(', ')}',
      );
    }
  }

  // Check if build configuration exists in Xcode project.
  if (buildConfiguration != null) {
    final buildConfigurations =
        await findBuildConfigurationsAvailable(platform, xcodeProjectPath);

    if (!buildConfigurations.contains(buildConfiguration)) {
      throw XcodeProjectException(
        platform,
        'XcodeProjectException: the build configuration "$buildConfiguration" does not exist in your Xcode workspace. Please choose one of the following build configurations: ${buildConfigurations.join(', ')}',
      );
    }
  }
}

String? _appleServiceFileValidation(
    String? serviceFilePath,
    String platform,
    String flutterAppPath,
  ) {
    if (serviceFilePath == null) {
      return null;
    }
    final fileName = path.basename(serviceFilePath);

    if (fileName == appleServiceFileName) {
      return path.join(
        flutterAppPath,
        removeForwardBackwardSlash(serviceFilePath),
      );
    }

    if (fileName.contains('.')) {
      throw ServiceFileException(
        platform,
        'The service file name must be `$appleServiceFileName`. Please provide a path to the file. e.g. `$platform/dev` or `$platform/dev/$appleServiceFileName`',
      );
    }

    return path.join(
      flutterAppPath,
      removeForwardBackwardSlash(serviceFilePath),
      appleServiceFileName,
    );
  }