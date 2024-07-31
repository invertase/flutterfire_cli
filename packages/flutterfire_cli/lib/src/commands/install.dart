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
  crashlytics(
    name: 'firebase_crashlytics',
    displayName: 'Crashlytics',
    useWeb: false,
  ),
  firestore(name: 'cloud_firestore', displayName: 'Firestore'),
  functions(name: 'cloud_functions', displayName: 'Functions'),
  database(name: 'firebase_database', displayName: 'Realtime Database'),
  dynamicLinks(
    name: 'firebase_dynamic_links',
    displayName: 'Dynamic Links',
    useWeb: false,
  ),
  inAppMessaging(
    name: 'firebase_in_app_messaging',
    displayName: 'In-App Messaging',
    useWeb: false,
  ),
  messaging(name: 'firebase_messaging', displayName: 'Messaging'),
  mlModelDownloader(
    name: 'firebase_ml_model_downloader',
    displayName: 'ML Model Downloader',
    useWeb: false,
  ),
  performance(name: 'firebase_performance', displayName: 'Performance'),
  remoteConfig(name: 'firebase_remote_config', displayName: 'Remote Config'),
  storage(name: 'firebase_storage', displayName: 'Storage'),
  vertexAi(
    name: 'firebase_vertexai',
    displayName: 'Vertex AI',
    usePlatformInterface: false,
    useWeb: false,
  ),
  ;

  const FlutterFirePlugins({
    required this.name,
    required this.displayName,
    this.usePlatformInterface = true,
    this.useWeb = true,
  });

  final String name;
  final String displayName;
  final bool usePlatformInterface;
  final bool useWeb;

  static List<String> get allPluginsPublicNames =>
      FlutterFirePlugins.values.map((plugin) => plugin.name).toList();
}

class InstallCommand extends FlutterFireCommand {
  InstallCommand(FlutterApp? flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();

    argParser.addOption(
      'plugins',
      help: 'A comma-separated list of plugins to install.',
      valueHelp: 'plugin1,plugin2',
    );

    argParser.addOption(
      'version',
      help: 'The version of the BoM to install.',
      valueHelp: 'version',
    );

    argParser.addFlag(
      'only-pubspec-plugins',
      help: 'Only install plugins that are in the pubspec.yaml file.',
      negatable: false,
    );
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
    if (argResults!['plugins'] != null) {
      final selectedPlugins = <FlutterFirePlugins>[];
      final selectedPluginNames = argResults!['plugins'] as String;
      final selectedPluginNamesList = selectedPluginNames.split(',');
      for (final pluginName in selectedPluginNamesList) {
        final plugin = FlutterFirePlugins.values.firstWhereOrNull(
          (element) => element.name == pluginName,
        );
        if (plugin != null) {
          selectedPlugins.add(plugin);
        }
      }
      return selectedPlugins;
    }

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
    const bomPath =
        'https://raw.githubusercontent.com/firebase/flutterfire/main/scripts/versions.json';

    final http = HttpClient();
    final request = await http.getUrl(Uri.parse(bomPath));
    final response = await request.close(); // sends the request
    final jsonString = await response.transform(utf8.decoder).join();
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    if (bomVersion == 'latest' ||
        bomVersion == 'master' ||
        bomVersion == 'main' ||
        bomVersion.contains('git')) {
      // The latest version is the first key in the JSON
      return ((json[json.keys.first] as Map)['packages'] as Map)
          .cast<String, String>();
    }

    if (!json.containsKey(bomVersion)) {
      throw Exception(
        'BoM version $bomVersion not found. Check the available versions at https://github.com/firebase/flutterfire/blob/main/VERSIONS.md',
      );
    }

    return ((json[bomVersion] as Map)['packages'] as Map)
        .cast<String, String>();
  }

  @override
  Future<void> run() async {
    // Get the BoM version number from the arguments
    late String bomVersion;

    if (argResults?.arguments.length == 1) {
      bomVersion = argResults!.arguments[0];
    } else if (argResults?['version'] != null) {
      bomVersion = argResults!['version'] as String;
    } else {
      stderr.writeln(
        'Usage for install command: flutterfire install <version>',
      );
      return;
    }

    try {
      commandRequiresFlutterApp();

      final pluginVersions = await _getPluginVersionsFromJSON(bomVersion);

      final pubSpec = flutterApp!.package.pubSpec;
      final listOfAlreadyInstalledPlugins = pubSpec.dependencies.keys
          .where(
            (element) =>
                FlutterFirePlugins.allPluginsPublicNames.contains(element),
          )
          .toList();

      late List<FlutterFirePlugins> selectedPlugins;
      if (argResults!['only-pubspec-plugins'] as bool) {
        selectedPlugins = FlutterFirePlugins.values
            .where(
              (element) => listOfAlreadyInstalledPlugins.contains(element.name),
            )
            .toList();
      } else {
        selectedPlugins = await _selectPlugins(pluginVersions);
      }

      final pluginsToDelete = listOfAlreadyInstalledPlugins
          .where(
            (element) =>
                !selectedPlugins.any((plugin) => plugin.name == element),
          )
          .toList();

      if (pluginsToDelete.isNotEmpty) {
        stdout.writeln('The following plugins will be removed:');
        for (final plugin in pluginsToDelete) {
          stdout.writeln(' - $plugin');
        }
        final removingSpinner = spinner(
          (done) {
            if (!done) {
              return 'Removing plugins ... ';
            }
            return 'Plugins removed.';
          },
        );

        await Process.run(
          'dart',
          [
            'pub',
            'remove',
            ...pluginsToDelete,
          ],
          workingDirectory: flutterApp!.package.path,
        );

        removingSpinner.done();
      }

      if (selectedPlugins.isEmpty) {
        stdout.writeln('No plugins selected.');
        return;
      }

      stdout.writeln('Installing the following plugins version:');
      for (final plugin in selectedPlugins) {
        stdout.writeln(
          ' - ${plugin.displayName}: ${pluginVersions[plugin.name]}',
        );
      }

      final installingSpinner = spinner(
        (done) {
          if (!done) {
            return 'Running `flutter pub get` ... ';
          }
          return 'New versions installed.';
        },
      );

      await Process.run(
        'dart',
        [
          'pub',
          'add',
          ...selectedPlugins.map((e) => '${e.name}:${pluginVersions[e.name]}'),
        ],
        workingDirectory: flutterApp!.package.path,
      );

      installingSpinner.done();

      // Overriding using git branch
      if (bomVersion == 'master' ||
          bomVersion == 'main' ||
          bomVersion.contains('git')) {
        final gitBranch = bomVersion.contains('git')
            ? bomVersion.replaceFirst('git:', '')
            : 'main';
        final gitSpinner = spinner(
          (done) {
            if (!done) {
              return 'Overriding using git branch $gitBranch ... ';
            }
            return 'Override using git branch $gitBranch done.';
          },
        );

        final gitInstructions = selectedPlugins
            .map(
              (e) => [
                'override:${e.name}:{"git":{"url":"https://github.com/firebase/flutterfire.git","ref":"$gitBranch","path":"packages/${e.name}/${e.name}"}}',
                if (e.usePlatformInterface)
                  'override:${e.name}_platform_interface:{"git":{"url":"https://github.com/firebase/flutterfire.git","ref":"$gitBranch","path":"packages/${e.name}/${e.name}_platform_interface"}}',
                if (e.useWeb)
                  'override:${e.name}_web:{"git":{"url":"https://github.com/firebase/flutterfire.git","ref":"$gitBranch","path":"packages/${e.name}/${e.name}_web"}}',
              ],
            )
            .expand((element) => element)
            .toList();
        final result = await Process.run(
          'dart',
          [
            'pub',
            'add',
            ...gitInstructions,
            '--directory',
            '.',
          ],
          workingDirectory: flutterApp!.package.path,
        );

        gitSpinner.done();

        if (result.exitCode != 0) {
          throw Exception(
            AnsiStyles.red('Failed to install plugins.\n\n${result.stderr}'),
          );
        }
      } else {
        // Remove the git overrides
        final gitOverrides = pubSpec.dependencyOverrides.keys
            .where(
              (element) => FlutterFirePlugins.allPluginsPublicNames.contains(
                element.split('_').first,
              ),
            )
            .toList();

        if (gitOverrides.isNotEmpty) {
          final gitOverrideSpinner = spinner(
            (done) {
              if (!done) {
                return 'Removing git overrides ... ';
              }
              return 'Git overrides removed.';
            },
          );

          await Process.run(
            'dart',
            [
              'pub',
              'remove',
              ...gitOverrides.map((e) => 'override:$e'),
            ],
            workingDirectory: flutterApp!.package.path,
          );

          gitOverrideSpinner.done();
        }
      }

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
