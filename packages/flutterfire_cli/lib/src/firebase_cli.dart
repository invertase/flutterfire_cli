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

import 'common/exception.dart';

/// Executes a command on the Firebase CLI and returns
/// the result as a parsed JSON Map.
/// Example:
///   final result = await runFirebaseCommand(['projects:list']);
///   print(result);
Future<Map<String, dynamic>> runFirebaseCommand(
  List<String> commandAndArgs, {
  String? project,
  String? account,
}) async {
  final workingDirectoryPath = Directory.current.path;
  final execArgs = [
    ...commandAndArgs,
    '--json',
    if (project != null) '--project="$project"',
    if (account != null) '--account="$account"',
  ];
  final process = await Process.run(
    'firebase',
    execArgs,
    workingDirectory: workingDirectoryPath,
  );

  final jsonString = process.stdout.toString();
  final commandResult = Map<String, dynamic>.from(
    const JsonDecoder().convert(jsonString) as Map,
  );

  if (process.exitCode > 0 || commandResult['status'] == 'error') {
    throw FirebaseCommandException(
      execArgs.join(' '),
      commandResult['error'] as String,
    );
  }

  return commandResult;
}
