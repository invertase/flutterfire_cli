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

import '../common/utils.dart';

import '../firebase.dart';
import '../firebase/firebase_configuration_file.dart';
import '../flutter_app.dart';

import 'base.dart';

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
      kBuildConfiguration,
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
      ) as Map<String, Map>;
      buildConfigurations.forEach((key, value) async {
        // ignore: cast_nullable_to_non_nullable
        final configuration = buildConfigurations[key] as Map<String, String>;
        await _updateServiceFile(
          configuration,
          platform,
        );
      });
    }
    final defaultMapKeys = [
      ...appleMapKeys,
      kDefaultConfig,
    ];
    final defaultConfigExists = doesNestedMapExist(
      firebaseJsonMap,
      defaultMapKeys,
    );

    if (defaultConfigExists) {
      await _updateServiceFile(
        getNestedMap(
          firebaseJsonMap,
          defaultMapKeys,
        ),
        platform,
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
      final targets =
          getNestedMap(firebaseJsonMap, targetMapKeys) as Map<String, Map>;
      targets.forEach((key, value) async {
        // ignore: cast_nullable_to_non_nullable
        final configuration = targets[key] as Map<String, String>;
        await _updateServiceFile(
          configuration,
          platform,
        );
      });
    }
  }

  Future<void> _writeDartConfigurationFile() async {

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

    final firebaseJsonMap = jsonDecode(readFirebaseJson) as Map<String, dynamic>;
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
            getNestedMap(firebaseJsonMap, buildConfigurationKeys) as Map<String, Map>;
        buildConfigurations.forEach((key, value) async {
          // ignore: cast_nullable_to_non_nullable
          final configuration = buildConfigurations[key] as Map<String, String>;
          await _updateServiceFile(configuration, kAndroid);
        });
      }
      final defaultConfigKeys = [
        ...androidKeys,
        kDefaultConfig,
      ];
      final defaultAndroidExists = doesNestedMapExist(firebaseJsonMap, defaultConfigKeys);

      if (defaultAndroidExists) {
        final defaultAndroid = getNestedMap(firebaseJsonMap, defaultConfigKeys);
        await _updateServiceFile(defaultAndroid, kAndroid);
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

    if(dartExists){
      final dartConfig = getNestedMap(
        firebaseJsonMap,
        [
          kFlutter,
          kPlatforms,
          kDart,
        ],
      );
      //TODO write build config file
      // await _updateServiceFile(dartConfig, kDart);
    // TODO - write firebase_options.dart file with all configs
    //       await FirebaseConfigurationFile(
    //   outputFilePath,
    //   flutterApp!,
    //   androidOptions: androidOptions,
    //   iosOptions: iosOptions,
    //   macosOptions: macosOptions,
    //   webOptions: webOptions,
    //   windowsOptions: windowsOptions,
    //   linuxOptions: linuxOptions,
    //   force: isCI || yes,
    //   overwriteFirebaseOptions: overwriteFirebaseOptions,
    // ).write();
    }
  }
}