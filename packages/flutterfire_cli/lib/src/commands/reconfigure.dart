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

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;

import '../common/strings.dart';
import '../common/utils.dart';

import '../firebase.dart';
import '../firebase/firebase_android_options.dart';
import '../firebase/firebase_android_writes.dart';
import '../firebase/firebase_apple_options.dart';
import '../firebase/firebase_apple_writes.dart';
import '../firebase/firebase_dart_configuration_write.dart';
import '../firebase/firebase_dart_options.dart';
import '../firebase/firebase_options.dart';
import '../flutter_app.dart';

import 'base.dart';

class ConfigFileWrite {
  ConfigFileWrite({
    required this.pathToConfig,
    required this.projectId,
    this.androidOptions,
    this.iosOptions,
    this.macosOptions,
    this.webOptions,
    this.windowsOptions,
  });
  String pathToConfig;
  String projectId;
  FirebaseOptions? androidOptions;
  FirebaseOptions? iosOptions;
  FirebaseOptions? macosOptions;
  FirebaseOptions? webOptions;
  FirebaseOptions? windowsOptions;
}

class Reconfigure extends FlutterFireCommand {
  Reconfigure(FlutterApp? flutterApp, {String? token}) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();
    _accessToken = token;
    argParser.addOption(
      'ci-access-token',
      valueHelp: 'ciAccessToken',
      hide: true,
      help:
          'Set the access token for making Firebase API requests. Required for CI environment.',
    );
  }

  @override
  final String description =
      'Updates the configurations for all build variants included in the "firebase.json" added by running `flutterfire configure`.';

  @override
  final String name = 'reconfigure';

  String? _accessToken;
  late Logger _logger;

  String? get accessToken {
    // If we call reconfigure from `flutterfire configure`, `argResults` will be null and throw exception
    if (argResults != null) {
      _accessToken ??= argResults!['ci-access-token'] as String?;
    }

    return _accessToken;
  }

  set accessToken(String? value) {
    _accessToken = value;
  }

  // Necessary as we don't have access to the logger when we run this command from `flutterfire configure`
  @override
  Logger get logger => globalResults != null
      ? globalResults!['verbose'] as bool
          ? Logger.verbose()
          : Logger.standard()
      : _logger;

  set logger(Logger value) {
    _logger = value;
  }

  Future<void> _updateServiceFile(
    Map<String, dynamic> configuration,
    String platform,
  ) async {
    // We pass access token for CI as the token won't be present in the "firebase-tools.json" file unless you login
    accessToken ??= await getAccessToken();

    final serviceFilePath = configuration[kFileOutput] as String;
    // ignore: cast_nullable_to_non_nullable
    final projectId = configuration[kProjectId] as String;
    // ignore: cast_nullable_to_non_nullable
    final appId = configuration[kAppId] as String;

    if (platform == kAndroid || platform == kIos || platform == kMacos) {
      final serviceFileContent =
          await getServiceFileContent(projectId, appId, accessToken!, platform);

      final serviceFilePathAbsolute =
          File(path.join(flutterApp!.package.path, serviceFilePath));

      if (!serviceFilePathAbsolute.existsSync()) {
        serviceFilePathAbsolute.createSync(recursive: true);
      }
      serviceFilePathAbsolute.writeAsStringSync(serviceFileContent);
    }
  }

  Future<void> _updateAppleServiceFiles(
    Map<String, dynamic> firebaseJsonMap,
    // ios or macos
    String platform,
  ) async {
    final appleMapKeys = [
      kFlutter,
      kPlatforms,
      platform,
    ];

    final buildConfigurationKeys = [
      ...appleMapKeys,
      kBuildConfiguration,
    ];
    final buildConfigurationsExist = doesNestedMapExist(
      firebaseJsonMap,
      buildConfigurationKeys,
    );

    if (buildConfigurationsExist) {
      await addFlutterFireDebugSymbolsScript(
        flutterAppPath: flutterApp!.package.path,
        platform: platform,
        logger: logger,
        projectConfiguration: ProjectConfiguration.buildConfiguration,
      );

      final buildConfigurations = getNestedMap(
        firebaseJsonMap,
        buildConfigurationKeys,
      );
      final futures = <Future<void>>[];

      buildConfigurations.forEach((key, dynamic value) {
        // ignore: cast_nullable_to_non_nullable
        final configuration = buildConfigurations[key] as Map<String, dynamic>;

        futures.add(
          _writeFile(
            _updateServiceFile(
              configuration,
              platform,
            ),
            '$platform "$appleServiceFileName" file write for build configuration: "$key"',
          ),
        );
      });

      await Future.wait(futures);
    }
    final defaultMapKeys = [
      ...appleMapKeys,
      kDefaultConfig,
    ];
    final defaultConfigurationExists = doesNestedMapExist(
      firebaseJsonMap,
      defaultMapKeys,
    );

    if (defaultConfigurationExists) {
      await addFlutterFireDebugSymbolsScript(
        flutterAppPath: flutterApp!.package.path,
        platform: platform,
        logger: logger,
        projectConfiguration: ProjectConfiguration.defaultConfig,
      );

      await _writeFile(
        _updateServiceFile(
          getNestedMap(
            firebaseJsonMap,
            defaultMapKeys,
          ),
          platform,
        ),
        '$platform "$appleServiceFileName" file write for default target (Runner)',
      );
    }
    final targetMapKeys = [
      ...appleMapKeys,
      kTargets,
    ];

    final targetConfigurationExists = doesNestedMapExist(
      firebaseJsonMap,
      targetMapKeys,
    );

    if (targetConfigurationExists) {
      final targets = getNestedMap(firebaseJsonMap, targetMapKeys);

      final futures = <Future<void>>[];
      targets.forEach((key, dynamic value) async {
        await addFlutterFireDebugSymbolsScript(
          target: key,
          flutterAppPath: flutterApp!.package.path,
          platform: platform,
          logger: logger,
          projectConfiguration: ProjectConfiguration.target,
        );
        // ignore: cast_nullable_to_non_nullable
        final configuration = targets[key] as Map<String, dynamic>;
        futures.add(
          _writeFile(
            _updateServiceFile(
              configuration,
              platform,
            ),
            '$platform "$appleServiceFileName" file write for target: "$key"',
          ),
        );
      });
      await Future.wait(futures);
    }
  }

  Future<void> _writeDartConfigurationFile(
    Map<String, dynamic> firebaseJsonMap,
  ) async {
    final dartConfig = getNestedMap(
      firebaseJsonMap,
      [
        kFlutter,
        kPlatforms,
        kDart,
      ],
    );

    final listOfConfigWrites =
        dartConfig.entries.map<Future<List<ConfigFileWrite>>>((entry) {
      final path = entry.key;
      final map = entry.value as Map<String, dynamic>;
      final configurations = map[kConfigurations] as Map<String, dynamic>;
      final projectId = map[kProjectId] as String;

      final configWrite = ConfigFileWrite(
        pathToConfig: path,
        projectId: projectId,
      );

      final appSDKConfigFutures = configurations.entries.map((entry) {
        final platform = entry.key;
        final appId = entry.value as String;

        return Future(() async {
          final platformFirebase = platform == kWindows ? kWeb : platform;
          final appSdkConfig = await getAppSdkConfig(
            appId: appId,
            platform: platformFirebase,
          );

          switch (platform) {
            case kAndroid:
              configWrite.androidOptions =
                  FirebaseAndroidOptions.convertConfigToOptions(
                appSdkConfig,
                appId,
                projectId,
              );
              break;
            case kIos:
              configWrite.iosOptions =
                  FirebaseAppleOptions.convertConfigToOptions(
                appSdkConfig,
                appId,
                projectId,
              );
              break;
            case kMacos:
              configWrite.macosOptions =
                  FirebaseAppleOptions.convertConfigToOptions(
                appSdkConfig,
                appId,
                projectId,
              );
              break;
            case kWeb:
              configWrite.webOptions =
                  FirebaseDartOptions.convertConfigToOptions(
                appSdkConfig,
                projectId,
              );
              break;
            case kWindows:
              configWrite.windowsOptions =
                  FirebaseDartOptions.convertConfigToOptions(
                appSdkConfig,
                projectId,
              );
              break;
            default:
              throw Exception(
                'Platform: $platform is not supported for "flutterfire reconfigure".',
              );
          }

          return configWrite;
        });
      }).toList();

      return Future(() async {
        final configWrites = await Future.wait(appSDKConfigFutures);
        return configWrites;
      });
    }).toList();

    final configWrites =
        (await Future.wait(listOfConfigWrites)).expand((x) => x).toList();

    for (final configWrite in configWrites) {
      final future = Future(() async {
        return FirebaseDartConfigurationWrite(
          configurationFilePath: configWrite.pathToConfig,
          firebaseProjectId: configWrite.projectId,
          flutterAppPath: flutterApp!.package.path,
          androidOptions: configWrite.androidOptions,
          iosOptions: configWrite.iosOptions,
          macosOptions: configWrite.macosOptions,
          webOptions: configWrite.webOptions,
          windowsOptions: configWrite.windowsOptions,
        ).write();
      });

      await _writeFile(future, 'Dart configuration file write');
    }
  }

  Future<void> _writeFile(Future writeFileFuture, String name) async {
    try {
      await writeFileFuture;
    } catch (e) {
      // ignore: avoid_print
      print(
        'Failed to write $name. Please report this issue at:https://github.com/invertase/flutterfire_cli. Exception: $e',
      );

      rethrow;
    }
  }

  @override
  Future<void> run() async {
    try {
      final firebaseJson = File(
        path.join(
          flutterApp!.package.path,
          'firebase.json',
        ),
      );

      if (!firebaseJson.existsSync()) {
        throw Exception(
          '"firebase.json" does not exist. Please run `flutterfire configure` first.',
        );
      }

      final readFirebaseJson = firebaseJson.readAsStringSync();

      final firebaseJsonMap =
          jsonDecode(readFirebaseJson) as Map<String, dynamic>;
      final androidKeys = [
        kFlutter,
        kPlatforms,
        kAndroid,
      ];

      final androidExists = doesNestedMapExist(firebaseJsonMap, androidKeys);
      if (androidExists) {
        final buildConfigurationKeys = [...androidKeys, kBuildConfiguration];
        final androidBuildConfigurationsExist =
            doesNestedMapExist(firebaseJsonMap, buildConfigurationKeys);

        await gradleContentUpdates(flutterApp!);

        if (androidBuildConfigurationsExist) {
          final buildConfigurations =
              getNestedMap(firebaseJsonMap, buildConfigurationKeys);
          final futures = <Future<void>>[];
          buildConfigurations.forEach((key, dynamic value) async {
            // ignore: cast_nullable_to_non_nullable
            final configuration =
                buildConfigurations[key] as Map<String, dynamic>;

            futures.add(
              _writeFile(
                _updateServiceFile(configuration, kAndroid),
                '$kAndroid $androidServiceFileName file write for build configuration: "$key"',
              ),
            );
          });
          await Future.wait(futures);
        }
        final defaultConfigKeys = [
          ...androidKeys,
          kDefaultConfig,
        ];

        final defaultAndroidExists =
            doesNestedMapExist(firebaseJsonMap, defaultConfigKeys);

        if (defaultAndroidExists) {
          final defaultAndroid =
              getNestedMap(firebaseJsonMap, defaultConfigKeys);

          await _writeFile(
            _updateServiceFile(defaultAndroid, kAndroid),
            '$kAndroid $androidServiceFileName file write for default service file',
          );
        }
      }

      final iosExists = doesNestedMapExist(
        firebaseJsonMap,
        [
          kFlutter,
          kPlatforms,
          kIos,
        ],
      );
      if (iosExists) {
        await _updateAppleServiceFiles(firebaseJsonMap, kIos);
      }

      final macosExists = doesNestedMapExist(
        firebaseJsonMap,
        [
          kFlutter,
          kPlatforms,
          kMacos,
        ],
      );
      if (macosExists) {
        await _updateAppleServiceFiles(firebaseJsonMap, kMacos);
      }

      final dartExists = doesNestedMapExist(
        firebaseJsonMap,
        [
          kFlutter,
          kPlatforms,
          kDart,
        ],
      );

      if (dartExists) {
        await _writeDartConfigurationFile(firebaseJsonMap);
      }
    } catch (e) {
      // need to set the exit code to 1 for running windows scripts via integration tests
      exitCode = 1;
      stderr.writeln(e);
    } finally {
      exit(exitCode);
    }
  }
}
