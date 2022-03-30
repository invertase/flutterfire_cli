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
import 'package:interact/interact.dart' as interact;
import 'package:path/path.dart';

import '../common/exception.dart';
import '../common/utils.dart';

const _defaultAppIdFileName = 'firebase_app_id_file.json';
const _keyGoogleAppId = 'GOOGLE_APP_ID';
const _keyFirebaseProjectId = 'FIREBASE_PROJECT_ID';

class FirebaseAppIDFile {
  FirebaseAppIDFile(
    this.outputDirectoryPath, {
    required this.appId,
    required this.firebaseProjectId,
    this.fileName = _defaultAppIdFileName,
  });

  final StringBuffer _stringBuffer = StringBuffer();

  final String outputDirectoryPath;

  final String fileName;

  final String appId;
  final String firebaseProjectId;

  Future<void> write() async {
    if (!Directory(outputDirectoryPath).existsSync()) {
      throw PlatformDirectoryDoesNotExistException(outputDirectoryPath);
    }

    final appIDFilePath = joinAll([outputDirectoryPath, fileName]);
    final outputFile = File(joinAll([Directory.current.path, appIDFilePath]));

    if (outputFile.existsSync() && !isCI) {
      final existingFileContents = await outputFile.readAsString();
      final existingFileContentsAsJson =
          json.decode(existingFileContents) as Map;
      final existingAppId =
          existingFileContentsAsJson[_keyGoogleAppId] as String;
      final existingFirebaseProjectId =
          existingFileContentsAsJson[_keyFirebaseProjectId] as String;
      // Only prompt overwrite if values are different.
      if (existingAppId != appId ||
          existingFirebaseProjectId != firebaseProjectId) {
        final shouldOverwrite = interact.Confirm(
          prompt:
              'Generated FirebaseAppID file ${AnsiStyles.cyan(appIDFilePath)} already exists (for app id "$existingAppId" on Firebase Project "$existingFirebaseProjectId"), do you want to override it?',
          defaultValue: true,
        ).interact();
        if (!shouldOverwrite) {
          throw FirebaseAppIDAlreadyExistsException(appIDFilePath);
        }
      }
    }
    _writeHeaderAndAppID(outputFile.path);
    outputFile.writeAsStringSync(_stringBuffer.toString());
  }

  void _writeHeaderAndAppID(String outputFile) {
    final fileData = {
      'file_generated_by': 'FlutterFire CLI',
      'purpose':
          'FirebaseAppID & ProjectID for this Firebase app in this directory',
      _keyGoogleAppId: appId,
      _keyFirebaseProjectId: firebaseProjectId,
    };
    _stringBuffer.write(const JsonEncoder.withIndent('  ').convert(fileData));
  }
}
