/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */
import 'dart:io';
import 'package:path/path.dart' as path;
import '../common/strings.dart';
import '../common/utils.dart';
import '../flutter_app.dart';
import 'base.dart';

class BundleServiceFile extends FlutterFireCommand {
  BundleServiceFile(FlutterApp? flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();

    argParser.addOption(
      'build-configuration',
      valueHelp: 'buildConfiguration',
      help: 'The name of the build configuration.',
    );

    argParser.addOption(
      'plist-destination',
      valueHelp: 'plistDestination',
      help:
          'The absolute path to the plist destination folder defined by Xcode environment variable.',
    );

    argParser.addOption(
      'apple-project-path',
      valueHelp: 'appleProjectPath',
      help:
          'The absolute path to the flutter app apple directory (macos/ or ios/ directory).',
    );

    argParser.addOption(
      'platform',
      valueHelp: 'platformName',
      help: 'Either "macos" or "ios"',
    );
  }

  @override
  final bool hidden = true;

  @override
  final String description =
      'Bundles GoogleService-Info.plist file to the correct plist directory for Xcode for the correct build configuration.';

  @override
  final String name = 'bundle-service-file';

  String get buildConfiguration {
    return argResults!['build-configuration'] as String;
  }

  String? get plistDestination {
    return argResults!['plist-destination'] as String?;
  }

  String get appleProjectPath {
    return argResults!['apple-project-path'] as String;
  }

  String get platform {
    return argResults!['platform'] as String;
  }

  @override
  Future<void> run() async {
    if (!Platform.isMacOS) return;

    final appleConfig =
        await appleConfigFromFirebaseJson(appleProjectPath, platform);
    final buildConfigurations =
        appleConfig[kBuildConfiguration] as Map<String, dynamic>;

    final configurationMap = buildConfigurations[buildConfiguration] as Map?;

    if (configurationMap == null) {
      logger.stdout(
        'You have not configured a "GoogleService-Info.plist" file with the build configuration: "$buildConfiguration"',
      );
      return;
    }

    final relativeServiceFilePath = configurationMap[kFileOutput] as String;

    final absoluteServiceFilePath =
        path.join(path.dirname(appleProjectPath), relativeServiceFilePath);

    final copyServiceFileToPlistDestination = await Process.run(
      'bash',
      ['-c', 'cp "$absoluteServiceFilePath" "$plistDestination"'],
    );

    if (copyServiceFileToPlistDestination.exitCode != 0) {
      throw Exception(copyServiceFileToPlistDestination.stderr);
    } else {
      logger.stdout(
        successfullyBundledServiceFile,
      );
    }
  }
}
