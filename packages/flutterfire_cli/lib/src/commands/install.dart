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

import '../common/utils.dart';
import '../flutter_app.dart';
import 'base.dart';

enum FlutterFirePlugins {
  core(name: 'firebase_core', displayName: 'Firebase Core'),
  analytics(name: 'firebase_analytics', displayName: 'Firebase Analytics'),
  auth(name: 'firebase_auth', displayName: 'Firebase Auth');

  const FlutterFirePlugins({required this.name, required this.displayName});

  final String name;
  final String displayName;
}

class InstallCommand extends FlutterFireCommand {
  InstallCommand(FlutterApp? flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();
  }

  @override
  final String name = 'install';

  @override
  List<String> aliases = <String>[
    'i',
  ];

  @override
  final String description =
      'Install a compatible version of plugins using a BoM version number.';

  Future<List<FlutterFirePlugins>> _selectPlugins() async {
    final selectedPlugins = <FlutterFirePlugins>[];
    final choices =
        FlutterFirePlugins.values.map((plugin) => plugin.displayName).toList();
    final selectedChoices = promptMultiSelect(
      'Select the Firebase plugins you would like to install',
      choices,
    );
    for (final index in selectedChoices) {
      selectedPlugins.add(FlutterFirePlugins.values[index]);
    }
    return selectedPlugins;
  }

  @override
  Future<void> run() async {
    try {
      commandRequiresFlutterApp();

      final selectedPlugins = await _selectPlugins();
    } catch (e) {
      // need to set the exit code to 1 for running windows scripts via integration tests
      exitCode = 1;
      stderr.writeln(e);
    } finally {
      exit(exitCode);
    }
  }
}
