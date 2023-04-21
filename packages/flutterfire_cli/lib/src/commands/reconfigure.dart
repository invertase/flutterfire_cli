/*

* Copyright (c) 2016-present Invertase Limited & Contributors

*

* Licensed under the Apache License, Version 2.0 (the "License");

* you may not use this library except in compliance with the License.

* You may obtain a copy of the License at

*

* http://www.apache.org/licenses/LICENSE-2.0

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

import 'package:path/path.dart' as path;

import '../common/strings.dart';
import '../common/utils.dart';

import '../firebase.dart';
import '../firebase/firebase_android_options.dart';
import '../firebase/firebase_apple_options.dart';
import '../firebase/firebase_configuration_file.dart';
import '../firebase/firebase_dart_options.dart';
import '../firebase/firebase_options.dart';
import '../flutter_app.dart';

import 'base.dart';

class ConfigFileWrite {
  ConfigFileWrite({
    required this.pathToConfig,
    required this.projectId,
    this.android,
    this.ios,
    this.macos,
    this.web,
  });
  String pathToConfig;
  String projectId;
  FirebaseOptions? android;
  FirebaseOptions? ios;
  FirebaseOptions? macos;
  FirebaseOptions? web;
}

class Reconfigure extends FlutterFireCommand {
  Reconfigure(FlutterApp? flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();
  }

  @override
  final String description =
      'Updates the configurations for all build variants included in the "firebase.json" added by running `flutterfire configure`.';

  @override
  final String name = 'reconfigure';

  String? accessToken;

  Future<void> _updateServiceFile(
    Map<String, dynamic> configuration,
    String platform,
  ) async {
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
      final buildConfigurations = getNestedMap(
        firebaseJsonMap,
        buildConfigurationKeys,
      );
      buildConfigurations.forEach((key, dynamic value) async {
        // ignore: cast_nullable_to_non_nullable
        final configuration = buildConfigurations[key] as Map<String, dynamic>;

        await _writeFile(
          _updateServiceFile(
            configuration,
            platform,
          ),
          '$platform "$appleServiceFileName" file write for build configuration: "$key"',
        );
      });
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
      targets.forEach((key, dynamic value) async {
        // ignore: cast_nullable_to_non_nullable
        final configuration = targets[key] as Map<String, dynamic>;
        await _writeFile(
          _updateServiceFile(
            configuration,
            platform,
          ),
          '$platform "$appleServiceFileName" file write for target: "$key"',
        );
      });
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
          final appSdkConfig = await getAppSdkConfig(
            appId: appId,
            platform: platform,
          );

          switch (platform) {
            case kAndroid:
              configWrite.android =
                  FirebaseAndroidOptions.convertConfigToOptions(
                appSdkConfig,
                appId,
                projectId,
              );
              break;
            case kIos:
              configWrite.ios = FirebaseAppleOptions.convertConfigToOptions(
                appSdkConfig,
                appId,
                projectId,
              );
              break;
            case kMacos:
              configWrite.macos = FirebaseAppleOptions.convertConfigToOptions(
                appSdkConfig,
                appId,
                projectId,
              );
              break;
            case kWeb:
              configWrite.web = FirebaseDartOptions.convertConfigToOptions(
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
        return FirebaseConfigurationFile(
          configurationFilePath: configWrite.pathToConfig,
          flutterAppPath: flutterApp!.package.path,
          androidOptions: configWrite.android,
          iosOptions: configWrite.ios,
          macosOptions: configWrite.macos,
          webOptions: configWrite.web,
        ).write();
      });

      await _writeFile(future, 'Dart configuration file write');
    }
  }

  Future<void> _writeFile(Future writeFileFuture, String name) async {
    try {
      await writeFileFuture;
    } catch (e) {
      throw Exception(
        'Failed to write $name. Please report this issue at:https://github.com/invertase/flutterfire_cli. Exception: $e',
      );
    }
  }

  @override
  Future<void> run() async {
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

      if (androidBuildConfigurationsExist) {
        final buildConfigurations =
            getNestedMap(firebaseJsonMap, buildConfigurationKeys);
        buildConfigurations.forEach((key, dynamic value) async {
          // ignore: cast_nullable_to_non_nullable
          final configuration =
              buildConfigurations[key] as Map<String, dynamic>;

          await _writeFile(
            _updateServiceFile(configuration, kAndroid),
            '$kAndroid $androidServiceFileName file write for build configuration: "$key"',
          );
        });
      }
      final defaultConfigKeys = [
        ...androidKeys,
        kDefaultConfig,
      ];
      stderr.write('KKKKKKK: $defaultConfigKeys');

      final defaultAndroidExists =
          doesNestedMapExist(firebaseJsonMap, defaultConfigKeys);

      if (defaultAndroidExists) {
        final defaultAndroid = getNestedMap(firebaseJsonMap, defaultConfigKeys);
        stderr.write('DDDDDDDDDD: $defaultAndroid');

        stderr.write('111111111: ${defaultAndroid.runtimeType}');
        await _updateServiceFile(defaultAndroid, kAndroid);
        
        stderr.write('22222222');

        // await _writeFile(
        //   future,
        //   '$kAndroid $androidServiceFileName file write for default service file',
        // );
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
  }
}
