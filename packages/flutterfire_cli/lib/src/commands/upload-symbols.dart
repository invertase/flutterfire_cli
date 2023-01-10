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
import '../common/strings.dart';
import '../flutter_app.dart';
import 'base.dart';

class UploadCrashlyticsSymbols extends FlutterFireCommand {
  UploadCrashlyticsSymbols(FlutterApp? flutterApp) : super(flutterApp) {
    setupDefaultFirebaseCliOptions();

    argParser.addOption(
      'uploadSymbolsScriptPath',
      valueHelp: 'uploadSymbolsScriptPath',
      help:
          'The absolute path to the upload symbols script path found in the Pod/FirebaseCrashlytics.',
    );

    argParser.addOption(
      'debugSymbolsPath',
      valueHelp: 'debugSymbolsPath',
      help: 'The absolute path to the debug symbols directory.',
    );

    argParser.addOption(
      'infoPlistPath',
      valueHelp: 'infoPlistPath',
      help: 'The absolute path to the Info.plist file.',
    );

    argParser.addOption(
      'scheme',
      valueHelp: 'schemeName',
      help: 'The name of the scheme.',
    );

    argParser.addOption(
      'flutterAppPath',
      valueHelp: 'flutterAppPath',
      help: 'The absolute path to the flutter app root.',
    );
  }

  @override
  final String description =
      'Upload Crashlytics debug symbols to Firebase Crashlytics server upon building application.';

  @override
  final String name = 'upload-crashlytics-symbols';

  String get uploadSymbolsScriptPath {
    return argResults!['uploadSymbolsScriptPath'] as String;
  }

  String get debugSymbolsPath {
    return argResults!['debugSymbolsPath'] as String;
  }

  String get infoPlistPath {
    return argResults!['infoPlistPath'] as String;
  }

  String get scheme {
    return argResults!['scheme'] as String;
  }

  String get flutterAppPath {
    return argResults!['flutterAppPath'] as String;
  }

  String get appIdFileName {
    return 'app_id_file.json';
  }

  String get appIdPropertyName {
    return 'GOOGLE_APP_ID';
  }

  String get projectIdPropertyName {
    return 'FIREBASE_PROJECT_ID';
  }

  Future<String> _findOrCreateAppIdFile(
      String pathToAppIdFile, String appId, String projectId) async {
    // Will do nothing if it already exists
    await Directory(pathToAppIdFile).create(recursive: true);
    final file = File('$pathToAppIdFile/$appIdFileName');

    if (file.existsSync()) {
      final fileAsString = await file.readAsString();

      final map = jsonDecode(fileAsString) as Map;

      final fileAppId = map[appIdPropertyName] as String?;

      if (appId == fileAppId) {
        // App ID matches the one from firebase.json, return the path
        return file.path;
      } else {
        // Update app ID to match the current one from firebase.json
        map[appIdPropertyName] = appId;
        final updatedMapJson = json.encode(map);
        file.writeAsStringSync(updatedMapJson);

        return file.path;
      }
    } else {
      // Create file if it does not exist
      await file.create(recursive: true);
      final map = {appIdPropertyName: appId, projectIdPropertyName: projectId};

      final mapJson = json.encode(map);

      file.writeAsStringSync(mapJson);

      return file.path;
    }
  }

  @override
  Future<void> run() async {
    // Pull values from firebase.json in root of project
    final firebaseJson =
        await File('$flutterAppPath/firebase.json').readAsString();

    final parsedJson = json.decode(firebaseJson) as Map;

    String? appId;
    String? projectId;
    try {
      final flutterConfig = parsedJson['flutter'] as Map?;
      final platform = flutterConfig?['platforms'] as Map?;
      final iosConfig = platform?['ios'] as Map?;
      final schemeConfig = iosConfig?[scheme] as Map?;
      final uploadDebugSymbols = schemeConfig?['uploadDebugSymbols'] as bool?;

      // Exit if the user chooses not to run debug upload symbol script
      if (uploadDebugSymbols == false || uploadDebugSymbols == null) return;

      appId = schemeConfig?['appId'] as String?;
      projectId = schemeConfig?['projectId'] as String?;

      if (projectId == null || appId == null) {
        throw FirebaseJsonException();
      }
    } on FirebaseJsonException {
      return;
    } catch (e) {
      throw FirebaseJsonException();
    }

    final appIdFileDirectory =
        '${Directory.current.path}/.dart_tool/flutterfire/platforms/ios/$scheme/$projectId';
    final appIdFilePath =
        await _findOrCreateAppIdFile(appIdFileDirectory, appId, projectId);
    // Validation script
    final validationScript = await Process.run(
      uploadSymbolsScriptPath,
      [
        '--build-phase',
        '--validate',
        '-ai',
        appId,
        '--flutter-project',
        appIdFilePath,
        debugSymbolsPath,
        // infoPlistPath,
      ],
    );

    if (validationScript.exitCode != 0) {
      throw Exception(validationScript.stderr);
    }

    // Upload script
    final uploadScript = await Process.run(
      uploadSymbolsScriptPath,
      [
        '--build-phase',
        '-ai',
        appId,
        '--flutter-project',
        appIdFilePath,
        debugSymbolsPath,
        // Removed this argument as debug symbols cannot be found with it
        // infoPlistPath,
      ],
    );

    if (uploadScript.exitCode != 0) {
      throw Exception(uploadScript.stderr);
    }
  }
}
