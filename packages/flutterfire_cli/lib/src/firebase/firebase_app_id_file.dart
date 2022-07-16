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
import 'package:path/path.dart';

import '../common/strings.dart';
import '../common/utils.dart';
import 'firebase_options.dart';

const _defaultAppIdFileName = 'firebase_app_id_file.json';
const _keyGoogleAppId = 'GOOGLE_APP_ID';
const _keyFirebaseProjectId = 'FIREBASE_PROJECT_ID';
const _keyGcmSenderId = 'GCM_SENDER_ID';

class FirebaseAppIDFile {
  FirebaseAppIDFile(
    this.outputDirectoryPath, {
    this.flavor,
    required this.options,
    this.fileName = _defaultAppIdFileName,
    this.force = false,
  });

  final StringBuffer _stringBuffer = StringBuffer();

  final String? flavor;
  final String outputDirectoryPath;

  /// Whether to skip prompts and force write output file.
  final bool force;

  final String fileName;

  final FirebaseOptions options;

  Future<void> write() async {
    if (!Directory(outputDirectoryPath).existsSync()) {
      throw PlatformDirectoryDoesNotExistException(outputDirectoryPath);
    }

    final mFileName =
        flavor != null ? 'firebase_app_id_file_$flavor.json' : fileName;
    final appIDFilePath = joinAll([outputDirectoryPath, mFileName]);
    final outputFile = File(joinAll([Directory.current.path, appIDFilePath]));

    _writeHeaderAndAppID(outputFile.path);
    final newFileContents = _stringBuffer.toString();

    if (outputFile.existsSync() && !force) {
      final existingFileContents = await outputFile.readAsString();
      // Only prompt overwrite if values are different.
      if (newFileContents != existingFileContents) {
        final shouldOverwrite = promptBool(
          'Generated FirebaseAppID file ${AnsiStyles.cyan(appIDFilePath)} already exists, do you want to override it?',
        );
        if (!shouldOverwrite) {
          throw FirebaseAppIDAlreadyExistsException(appIDFilePath);
        }
      }
    }
    outputFile.writeAsStringSync(newFileContents);
  }

  void _writeHeaderAndAppID(String outputFile) {
    final fileData = {
      'file_generated_by': 'FlutterFire CLI',
      'purpose':
          'FirebaseAppID & ProjectID for this Firebase app in this directory',
      _keyGoogleAppId: options.appId,
      _keyFirebaseProjectId: options.projectId,
      _keyGcmSenderId: options.messagingSenderId,
    };
    _stringBuffer.write(const JsonEncoder.withIndent('  ').convert(fileData));
  }
}
