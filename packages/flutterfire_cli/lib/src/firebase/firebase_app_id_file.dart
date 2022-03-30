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

class FirebaseAppIDFile {
  FirebaseAppIDFile(this.outputDirectoryPath, this.fileName, this.appId);

  final StringBuffer _stringBuffer = StringBuffer();

  final String outputDirectoryPath;

  final String fileName;

  final String appId;

  Future<void> write() async {
    // ignore: avoid_slow_async_io
    final directoryExists = await Directory(outputDirectoryPath).exists();
    if (!directoryExists) {
      throw PlatformDirectoryDoesNotExistException(outputDirectoryPath);
    }
    final appIDFilePath = joinAll([outputDirectoryPath, fileName]);
    final outputFile = File(joinAll([Directory.current.path, appIDFilePath]));
    if (outputFile.existsSync() && !isCI) {
      final shouldOverwrite = interact.Confirm(
        prompt:
            'Generated FirebaseAppID file ${AnsiStyles.cyan(appIDFilePath)} already exists, do you want to override it?',
        defaultValue: true,
      ).interact();
      if (!shouldOverwrite) {
        throw FirebaseAppIDAlreadyExistsException(appIDFilePath);
      }
    }
    _writeHeaderAndAppID(outputFile.path);
    outputFile.writeAsStringSync(_stringBuffer.toString());
  }

  void _writeHeaderAndAppID(String outputFile) {
    final fileData = {
      'file_generated_by': 'FlutterFire CLI',
      'purpose': 'FirebaseAppID for this Firebase app in this directory',
      'GOOGLE_APP_ID': appId
    };
    _stringBuffer.write(json.encode(fileData));
  }
}
