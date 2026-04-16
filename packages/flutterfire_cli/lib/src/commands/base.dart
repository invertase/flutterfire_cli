/*
 * Copyright (c) 2020-present Invertase Limited & Contributors
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

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;

import '../common/strings.dart';
import '../common/utils.dart';
import '../flutter_app.dart';

/// A base class for all FlutterFire commands.
abstract class FlutterFireCommand extends Command<void> {
  FlutterFireCommand(this.flutterApp);

  final FlutterApp? flutterApp;

  Logger get logger =>
      globalResults!['verbose'] as bool ? Logger.verbose() : Logger.standard();

  String? get projectId {
    return argResults!['project'] as String?;
  }

  String? get accountEmail {
    return argResults!['account'] as String?;
  }

  /// Resolves the path to the `firebase.json` file.
  ///
  /// If a [customPath] is provided, it is returned directly if it is absolute.
  /// If it is relative, it is resolved relative to the project root (`FlutterApp.package.path`).
  /// If no [customPath] is provided, it defaults to `firebase.json` in the project root.
  String resolveFirebaseJsonPath(String? customPath) {
    if (customPath != null) {
      // If a custom path was provided, check if it is relative.
      if (path.isRelative(customPath)) {
        // Resolve relative paths relative to the project root to ensure consistent behavior.
        return path.join(flutterApp!.package.path, customPath);
      }
      // Use absolute paths as provided.
      return customPath;
    }
    // Default to the standard firebase.json in the project root if no custom path is specified.
    return path.join(flutterApp!.package.path, 'firebase.json');
  }

  void setupDefaultFirebaseCliOptions() {
    argParser.addOption(
      'project',
      valueHelp: 'aliasOrProjectId',
      abbr: 'p',
      help: 'The Firebase project to use for this command.',
    );
    argParser.addOption(
      'account',
      valueHelp: 'email',
      abbr: 'e',
      help: 'The Google account to use for authorization.',
    );

    argParser.addFlag(
      'debug',
      abbr: 'd',
      help: 'Use debug logger for additional output.',
    );
  }

  void commandRequiresFlutterApp() {
    if (flutterApp == null) {
      throw FlutterAppRequiredException();
    }
    _warnUserIfRunningGlobally();
  }

  // Warns user if they have a dev dependency on flutterfire_cli and are running globally
  void _warnUserIfRunningGlobally() {
    final scriptPath = Platform.script.toFilePath();

    // Check if we're in a .dart_tool directory (dev dependency)
    if (!scriptPath.contains('.dart_tool') &&
        flutterApp!.dependsOnPackage('flutterfire_cli')) {
      logger.stdout(
        "If you're trying to run FlutterFire CLI as a dev dependency, you need to run `dart run flutterfire_cli:flutterfire` instead of `flutterfire`",
      );
    }
  }

  /// Overridden to support line wrapping when printing usage.
  @override
  late final ArgParser argParser = ArgParser(
    usageLineLength: terminalWidth,
  );
}
