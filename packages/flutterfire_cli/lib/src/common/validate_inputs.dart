import 'dart:io';

import 'package:path/path.dart' as path;
import 'strings.dart';
import 'utils.dart';

class ValidateInputs {
  ValidateInputs(
    this.iosBuildConfiguration,
    this.iosTarget,
    this.iOSServiceFilePath,
    this.macosBuildConfiguration,
    this.macosTarget,
    this.macOSServiceFilePath,
  );

  String? iosBuildConfiguration;
  String? iosTarget;
  String? iOSServiceFilePath;
  String? macosBuildConfiguration;
  String? macosTarget;
  String? macOSServiceFilePath;

  Future<void> validate() async {
    await _validateAppleInputs();
  }

  String xcodeProjFilePath(String platform) {
    return path.join(
      Directory.current.path,
      platform,
      'Runner.xcodeproj',
    );
  }

  Future<List<String>> _findTargetsAvailable(String platform) async {
    final targetScript = '''
      require 'xcodeproj'
      xcodeProject='${xcodeProjFilePath(platform)}'
      project = Xcodeproj::Project.open(xcodeProject)

      response = Array.new

      project.targets.each do |target|
        response << target.name
      end

      if response.length == 0
        abort("There are no targets in your Xcode workspace. Please create a target and try again.")
      end

      \$stdout.write response.join(',')
    ''';

    final result = await Process.run('ruby', [
      '-e',
      targetScript,
    ]);

    if (result.exitCode != 0) {
      throw Exception(result.stderr);
    }
    // Retrieve the targets to to check if it exists on the project
    final targets = (result.stdout as String).split(',');

    return targets;
  }

  Future<List<String>> _findBuildConfigurationsAvailable(
      String platform) async {
    final buildConfigurationScript = '''
      require 'xcodeproj'
      xcodeProject='${xcodeProjFilePath(platform)}'

      project = Xcodeproj::Project.open(xcodeProject)

      response = Array.new

      project.build_configurations.each do |configuration|
        response << configuration
      end

      if response.length == 0
        abort("There are no build configurations in your Xcode workspace. Please create a build configuration and try again.")
      end

      \$stdout.write response.join(',')
    ''';

    final result = await Process.run('ruby', [
      '-e',
      buildConfigurationScript,
    ]);

    if (result.exitCode != 0) {
      throw Exception(result.stderr);
    }
    // Retrieve the build configurations to check if it exists on the project
    final buildConfigurations = (result.stdout as String).split(',');

    return buildConfigurations;
  }

  Future<void> _validateAppleInputs() async {
    // Cannot have build configuration and target setup at the same time.
    if (iosBuildConfiguration != null && iosTarget != null) {
      throw XcodeProjectException(
        kIos,
        'XcodeProjectException: choose either a "$kIos-target" or a "$kIos-scheme" for your $kIos project setup',
      );
    }

    // Cannot have build configuration and target setup at the same time.
    if (macosBuildConfiguration != null && macosTarget != null) {
      throw XcodeProjectException(
        kMacos,
        'XcodeProjectException: choose either a "$kMacos-target" or a "$kMacos-scheme" for your $kMacos project setup',
      );
    }
    // Need to specify a path to service file for target or build configuration.
    if ((iosTarget != null || iosBuildConfiguration != null) &&
        iOSServiceFilePath == null) {
      throw ServiceFileException(
        kIos,
        'Please specify a path to your $appleServiceFileName service file using the `--ios-out` flag.',
      );
    }

    // Need to specify a path to service file for target or build configuration.
    if ((macosTarget != null || macosBuildConfiguration != null) &&
        macOSServiceFilePath == null) {
      throw ServiceFileException(
        kIos,
        'Please specify a path to your $appleServiceFileName service file using the `--macos-out` flag.',
      );
    }

    // Need to specify a target or build configuration if you have specified a path to service file.
    if ((iosTarget == null && iosBuildConfiguration == null) &&
        iOSServiceFilePath != null) {
      throw XcodeProjectException(
        kIos,
        'Please specify a target using the `--ios-target` flag OR a build configuration with the `--ios-build-config` flag.',
      );
    }

    // Need to specify a target or build configuration if you have specified a path to service file.
    if ((macosTarget == null && macosBuildConfiguration == null) &&
        macOSServiceFilePath != null) {
      throw XcodeProjectException(
        kMacos,
        'Please specify a target using the `--macos-target` flag OR a build configuration with the `--macos-build-config` flag.',
      );
    }

    // Check if target exists in Xcode project.
    if (iosTarget != null) {
      final targets = await _findTargetsAvailable(kIos);
      if (!targets.contains(iosTarget)) {
        throw XcodeProjectException(
          kIos,
          'XcodeProjectException: the target "$iosTarget" does not exist in your Xcode workspace. Please choose one of the following targets: ${targets.join(', ')}',
        );
      }
    }

    // Check if target exists in Xcode project.
    if (macosTarget != null) {
      final targets = await _findTargetsAvailable(kMacos);

      if (!targets.contains(macosTarget)) {
        throw XcodeProjectException(
          kMacos,
          'XcodeProjectException: the target "$macosTarget" does not exist in your Xcode workspace. Please choose one of the following targets: ${targets.join(', ')}',
        );
      }
    }
    // Check if build configuration exists in Xcode project.
    if (iosBuildConfiguration != null) {
      final buildConfigurations = await _findBuildConfigurationsAvailable(kIos);

      if (!buildConfigurations.contains(iosBuildConfiguration)) {
        throw XcodeProjectException(
          kIos,
          'XcodeProjectException: the build configuration "$iosBuildConfiguration" does not exist in your Xcode workspace. Please choose one of the following build configurations: ${buildConfigurations.join(', ')}',
        );
      }
    }

    // Check if build configuration exists in Xcode project.
    if (macosBuildConfiguration != null) {
      final buildConfigurations =
          await _findBuildConfigurationsAvailable(kMacos);

      if (!buildConfigurations.contains(macosBuildConfiguration)) {
        throw XcodeProjectException(
          kMacos,
          'XcodeProjectException: the build configuration "$macosBuildConfiguration" does not exist in your Xcode workspace. Please choose one of the following build configurations: ${buildConfigurations.join(', ')}',
        );
      }
    }
  }
}
