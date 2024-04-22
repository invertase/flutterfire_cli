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

import 'dart:convert';
import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:collection/collection.dart';
import 'package:pubspec/pubspec.dart';

import '../common/utils.dart';
import '../flutter_app.dart';
import 'base.dart';

enum FlutterFirePlugins {
  core(name: 'firebase_core', displayName: 'Core'),
  analytics(name: 'firebase_analytics', displayName: 'Analytics'),
  auth(name: 'firebase_auth', displayName: 'Authentication'),
  appCheck(name: 'firebase_app_check', displayName: 'App Check'),
  appInstallations(
    name: 'firebase_app_installations',
    displayName: 'App Installations',
  ),
  crashlytics(name: 'firebase_crashlytics', displayName: 'Crashlytics'),
  firestore(name: 'cloud_firestore', displayName: 'Firestore'),
  functions(name: 'cloud_functions', displayName: 'Functions'),
  database(name: 'firebase_database', displayName: 'Realtime Database'),
  dynamicLinks(name: 'firebase_dynamic_links', displayName: 'Dynamic Links'),
  inAppMessaging(
    name: 'firebase_in_app_messaging',
    displayName: 'In-App Messaging',
  ),
  messaging(name: 'firebase_messaging', displayName: 'Messaging'),
  mlModelDownloader(
    name: 'firebase_ml_model_downloader',
    displayName: 'ML Model Downloader',
  ),
  performance(name: 'firebase_performance', displayName: 'Performance'),
  remoteConfig(name: 'firebase_remote_config', displayName: 'Remote Config'),
  storage(name: 'firebase_storage', displayName: 'Storage');

  const FlutterFirePlugins({required this.name, required this.displayName});

  final String name;
  final String displayName;

  static List<String> get allPluginsPublicNames =>
      FlutterFirePlugins.values.map((plugin) => plugin.name).toList();
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

  Future<List<FlutterFirePlugins>> _selectPlugins(
    Map<String, String> availablePlugins,
  ) async {
    final selectedPlugins = <FlutterFirePlugins>[];
    final listAvailablePluginsInVersion = availablePlugins.keys.toList();
    final choices = FlutterFirePlugins.values
        .where(
          (element) => listAvailablePluginsInVersion.contains(element.name),
        )
        .map((plugin) => plugin.displayName)
        .toList();
    final defaultSelection = List<bool>.filled(choices.length, false);
    for (final dependency in flutterApp!.package.dependencies) {
      final enumValue = FlutterFirePlugins.values.firstWhereOrNull(
        (element) => element.name == dependency,
      );
      if (enumValue != null) {
        final index = choices.indexOf(enumValue.displayName);
        defaultSelection[index] = true;
      }
    }
    // Firebase Core is always selected
    defaultSelection[0] = true;

    final selectedChoices = promptMultiSelect(
      'Select the Firebase plugins you would like to install',
      choices,
      defaultSelection: defaultSelection,
    );
    for (final index in selectedChoices) {
      selectedPlugins.add(FlutterFirePlugins.values[index]);
    }
    return selectedPlugins;
  }

  Future<Map<String, String>> _getPluginVersionsFromJSON(
    String bomVersion,
  ) async {
    // TODO: change to master
    const bomPath =
        'https://raw.githubusercontent.com/firebase/flutterfire/chore/proposal/scripts/versions.json';

    final http = HttpClient();
    final request = await http.getUrl(Uri.parse(bomPath));
    final response = await request.close(); // sends the request
    final jsonString = await response.transform(utf8.decoder).join();
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    if (!json.containsKey(bomVersion)) {
      throw Exception(
        'BoM version $bomVersion not found. Check the available versions at https://github.com/firebase/flutterfire/blob/chore/proposal/VERSIONS.md',
      );
    }

    return ((json[bomVersion] as Map)['packages'] as Map)
        .cast<String, String>();
  }

  @override
  Future<void> run() async {
    // Get the BoM version number from the arguments
    if (argResults?.arguments.length != 1) {
      stderr.writeln(
        'Usage for install command: flutterfire install <version>',
      );
      return;
    }
    final bomVersion = argResults!.arguments[0];

    try {
      commandRequiresFlutterApp();

      final pluginVersions = await _getPluginVersionsFromJSON(bomVersion);

      final selectedPlugins = await _selectPlugins(pluginVersions);

      if (selectedPlugins.isEmpty) {
        stdout.writeln('No plugins selected.');
        return;
      }

      final pubSpec = flutterApp!.package.pubSpec;

      final filteredDependencies = <String, DependencyReference>{};
      // Removing all existing Firebase plugins from the pubspec
      for (final dependency in pubSpec.dependencies.keys) {
        if (!FlutterFirePlugins.allPluginsPublicNames.contains(dependency)) {
          filteredDependencies[dependency] = pubSpec.dependencies[dependency]!;
        }
      }

      final newPubSpec = pubSpec.copy(
        dependencies: {
          for (final plugin in selectedPlugins)
            plugin.name: HostedReference.fromJson(
              pluginVersions[plugin.name]!,
            ),
          ...filteredDependencies,
        },
      );

      await newPubSpec.save(Directory(flutterApp!.package.path));

      stdout.writeln('Updated `pubspec.yaml` with the following plugins:');
      for (final plugin in selectedPlugins) {
        stdout.writeln(
          ' - ${plugin.displayName}: ${pluginVersions[plugin.name]}',
        );
      }

      final installingSpinner = spinner(
        (done) {
          if (!done) {
            return 'Installing new versions of plugins ... ';
          }
          return 'New versions installed.';
        },
      );

      await Process.run(
        'flutter',
        ['pub', 'get'],
        workingDirectory: flutterApp!.package.path,
      );

      installingSpinner.done();

      stdout.writeln(
        AnsiStyles.green(
          'Successfully installed BoM version $bomVersion 🚀',
        ),
      );
    } catch (e) {
      // need to set the exit code to 1 for running windows scripts via integration tests
      exitCode = 1;
      stderr.writeln(e);
    } finally {
      exit(exitCode);
    }
  }
}
