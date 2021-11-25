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

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import '../version.g.dart';
import 'common/utils.dart';

/// A class that can run FlutterFire commands.
///
/// To run a command, do:
///
/// ```dart
/// final flutterFire = FlutterFireCommandRunner();
///
/// await FlutterFireCommandRunner.run(['config']);
/// ```
class FlutterFireCommandRunner extends CommandRunner<void> {
  FlutterFireCommandRunner()
      : super(
          'flutterfire',
          'A CLI tool for FlutterFire projects.',
          usageLineLength: terminalWidth,
        ) {
    argParser.addFlag(
      'verbose',
      negatable: false,
      help: 'Enable verbose logging.',
    );
    argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the current CLI version.',
    );

    // TODO add commands
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] == true) {
      // ignore: avoid_print
      print(cliVersion);
      return;
    }
    await super.runCommand(topLevelResults);
  }
}
