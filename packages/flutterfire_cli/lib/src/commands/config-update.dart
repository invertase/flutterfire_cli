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

class ConfigUpdate extends FlutterFireCommand {
  ConfigUpdate(FlutterApp? flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();
  }

  @override
  final String description =
      'Updates the configurations for all build variants included in the "firebase.json" added by running `flutterfire configure`.';

  @override
  final String name = 'config-update';

  String? accessToken;

  Future<void> updateServiceFile(
    Map<String, dynamic> configuration,
    String platform,
  ) async {
    accessToken ??= await getAccessToken();

    final serviceFilePath = configuration[kServiceFileOutput] as String;
    // ignore: cast_nullable_to_non_nullable
    final projectId = configuration[kProjectId] as String;
    // ignore: cast_nullable_to_non_nullable
    final appId = configuration[kAppId] as String;

    if(platform == kAndroid || platform == kIos || platform == kMacos) {
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

  Future<void> updateAppleServiceFiles(
    Map<String, dynamic> maps,
  ) async {
    final buildConfigurations = maps[kBuildConfiguration] as Map<String, Map>?;

    if (buildConfigurations != null) {
      buildConfigurations.forEach((key, value) async {
        // ignore: cast_nullable_to_non_nullable
        final configuration = buildConfigurations[key] as Map<String, String>;
        await updateServiceFile(configuration, kIos);
      });
    }
    final defaultIos = maps[kDefaultConfig] as Map<String, dynamic>?;

    if (defaultIos != null) {
      await updateServiceFile(defaultIos, kIos);
    }

    final targets = maps[kTargets] as Map<String, Map>?;

    if (targets != null) {
      targets.forEach((key, value) async {
        // ignore: cast_nullable_to_non_nullable
        final configuration = targets[key] as Map<String, String>;
        await updateServiceFile(configuration, kIos);
      });
    }
  }

  @override
  Future<void> run() async {
    final firebaseJson = File('${flutterApp!.package.path}/firebase.json');

    if (!firebaseJson.existsSync()) {
      throw Exception(
        '"firebase.json" does not exist. Please run `flutterfire configure` first.',
      );
    }

    final readFirebaseJson = firebaseJson.readAsStringSync();

    final map = jsonDecode(readFirebaseJson) as Map;

    final flutterConfig = map[kFlutter] as Map;

    final platform = flutterConfig[kPlatforms] as Map;

    final android = platform[kAndroid] as Map?;
    if (android != null) {
      final buildConfigurations =
          android[kBuildConfiguration] as Map<String, Map>?;

      if (buildConfigurations != null) {
        buildConfigurations.forEach((key, value) async {
          // ignore: cast_nullable_to_non_nullable
          final configuration = buildConfigurations[key] as Map<String, String>;
          await updateServiceFile(configuration, kAndroid);
        });
      }
      final defaultAndroid = android[kDefaultConfig] as Map<String, dynamic>?;

      if (defaultAndroid != null) {
        await updateServiceFile(defaultAndroid, kAndroid);
      }
    }

    final ios = platform[kIos] as Map<String, dynamic>?;
    if (ios != null) {
      await updateAppleServiceFiles(ios);
    }

    final macos = platform[kMacos] as Map<String, dynamic>?;
    if (macos != null) {
      await updateAppleServiceFiles(macos);
    }

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
