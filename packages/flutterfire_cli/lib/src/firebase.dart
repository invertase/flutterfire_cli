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
import 'common/utils.dart';
import 'firebase/firebase_app.dart';
import 'firebase/firebase_project.dart';

/// Simple check to verify Firebase Tools CLI is installed.
bool? _existsCache;
Future<bool> exists() async {
  if (_existsCache != null) {
    return _existsCache!;
  }
  final process = await Process.run(
    'firebase',
    ['--version'],
  );
  return _existsCache = process.exitCode == 0;
}

/// Tries to read the default Firebase project id from the
/// .firbaserc file at the root of the dart project if it exists.
Future<String?> getDefaultFirebaseProjectId() async {
  final firebaseRcFile = File(firebaseRcPathForDirectory(Directory.current));
  if (!firebaseRcFile.existsSync()) return null;
  final fileContents = firebaseRcFile.readAsStringSync();
  try {
    final jsonMap =
        const JsonDecoder().convert(fileContents) as Map<String, dynamic>;
    if (jsonMap['projects'] != null &&
        (jsonMap['projects'] as Map)['default'] != null) {
      return (jsonMap['projects'] as Map)['default'] as String;
    }
  } catch (e) {
    return null;
  }
}

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
  final cliExists = await exists();
  if (!cliExists) {
    throw FirebaseCommandException(
      '--version',
      'The FlutterFire CLI currently requires the official Firebase CLI to also be installed, '
          'see https://firebase.google.com/docs/cli#install_the_firebase_cli for how to install it.',
    );
  }
  final workingDirectoryPath = Directory.current.path;
  final execArgs = [
    ...commandAndArgs,
    '--json',
    if (project != null) '--project=$project',
    if (account != null) '--account=$account',
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

/// Get all available Firebase projects for the authenticated CLI user
/// or for the account provided.
Future<List<FirebaseProject>> getProjects({
  String? account,
}) async {
  final response =
      await runFirebaseCommand(['projects:list'], account: account);
  final result = List<Map<String, dynamic>>.from(response['result'] as List);
  return result
      .map<FirebaseProject>(
        (Map<String, dynamic> e) =>
            FirebaseProject.fromJson(Map<String, dynamic>.from(e)),
      )
      .where((project) => project.state == 'ACTIVE')
      .toList();
}

/// Create a new [FirebaseProject].
Future<FirebaseProject> createProject({
  required String projectId,
  String? displayName,
  String? account,
}) async {
  final response = await runFirebaseCommand(
    [
      'projects:create',
      projectId,
      if (displayName != null) displayName,
    ],
    account: account,
  );
  final result = Map<String, dynamic>.from(response['result'] as Map);
  return FirebaseProject.fromJson(<String, dynamic>{
    ...Map<String, dynamic>.from(result),
    'state': 'ACTIVE'
  });
}

/// Get registered Firebase apps for a project.
Future<List<FirebaseApp>> getApps({
  required String project,
  String? account,
}) async {
  final response = await runFirebaseCommand(
    ['apps:list'],
    project: project,
    account: account,
  );
  final result = List<Map<String, dynamic>>.from(response['result'] as List);
  return result
      .map<FirebaseApp>(
        (Map<String, dynamic> e) =>
            FirebaseApp.fromJson(Map<String, dynamic>.from(e)),
      )
      .toList();
}

/// Create a new web [FirebaseApp].
Future<FirebaseApp> createWebApp({
  required String project,
  required String displayName,
  String? account,
}) async {
  final response = await runFirebaseCommand(
    [
      'apps:create',
      'web',
      displayName,
    ],
    project: project,
    account: account,
  );
  final result = Map<String, dynamic>.from(response['result'] as Map);
  return FirebaseApp.fromJson(<String, dynamic>{
    ...Map<String, dynamic>.from(result),
    'platform': 'WEB'
  });
}

/// Create a new android [FirebaseApp].
Future<FirebaseApp> createAndroidApp({
  required String project,
  required String displayName,
  required String packageName,
  String? account,
}) async {
  final response = await runFirebaseCommand(
    [
      'apps:create',
      'android',
      displayName,
      '--package-name=$packageName',
    ],
    project: project,
    account: account,
  );
  final result = Map<String, dynamic>.from(response['result'] as Map);
  return FirebaseApp.fromJson(<String, dynamic>{
    ...Map<String, dynamic>.from(result),
    'platform': 'ANDROID'
  });
}

/// Create a new iOS or macOS [FirebaseApp].
Future<FirebaseApp> createAppleApp({
  required String project,
  required String displayName,
  required String bundleId,
  String? account,
}) async {
  final response = await runFirebaseCommand(
    [
      'apps:create',
      'ios',
      displayName,
      '--bundle-id=$bundleId',
    ],
    project: project,
    account: account,
  );
  final result = Map<String, dynamic>.from(response['result'] as Map);
  return FirebaseApp.fromJson(<String, dynamic>{
    ...Map<String, dynamic>.from(result),
    'platform': 'IOS'
  });
}
