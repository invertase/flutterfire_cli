/*
 * Copyright (c) 2020-present Invertase Limited & Contributors
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

import 'package:ansi_styles/extension.dart';

/// Link to the Flutter specific documentation on the Firebase website.
const firebaseDocumentationUrl =
    'https://firebase.google.com/docs/flutter/setup';

/// Logs when the user runs any FlutterFire CLI command that requires the
/// Firebase CLI to be installed but it could not be found.
const logMissingFirebaseCli =
    'The FlutterFire CLI currently requires the official Firebase CLI to also be installed, '
    'see https://firebase.google.com/docs/cli#install_the_firebase_cli for how to install it.';

/// Prompts when the FlutterFire CLI detects that a new version of itself is available.
/// This behavior is only triggered when running `flutterfire --version`.
String logPromptNewCliVersionAvailable(
  String packageName,
  String latestVersion,
) =>
    'There is a new version of $packageName available ($latestVersion). '
    'Would you like to update?';

/// Logs once the FlutterFire CLI has been updated via autoupdate flow triggered by `flutterfire --version`.
String logCliUpdated(String packageName, String latestVersion) =>
    '$packageName has been updated to version $latestVersion.';

/// Logs when the `--no-app-id-json` flag is used. See the following link for
/// context on why a flag to opt-out was added:
/// https://github.com/invertase/flutterfire_cli/issues/14
const logSkippingAppIdJson =
    'Skipping `firebase_app_id_file.json` generation. Note: this is not '
    'recommended as it can cause configuration issues with some FlutterFire '
    'plugins such as Crashlytics.';

/// Logs when the configure command is completed. Printed apps after are in a table format.
String logFirebaseConfigGenerated(String outputFilePath) =>
    'Firebase configuration file ${outputFilePath.cyan} generated '
    'successfully with the following Firebase apps:';

/// Logs when the configure command is completed, after [logFirebaseConfigGenerated]
/// (and its table of apps) is printed.
const logLearnMoreAboutCli =
    'Learn more about using this file and next steps from the documentation:\n'
    ' > $firebaseDocumentationUrl';

/// Prompts when Android Google Services JSON file already exists but contains
/// configuration values for a different Firebase project.
String logPromptReplaceGoogleServicesJson(
  String fileName,
  String currentProjectId,
  String newProjectId,
) =>
    'The ${fileName.cyan} file already exists but for a different '
    'Firebase project (${currentProjectId.grey}). Do you want to '
    'replace it with Firebase project ${newProjectId.green}?';

/// Logs when the result of [logPromptReplaceGoogleServicesJson] is false (do not replace).
String logSkippingGoogleServicesJson(String fileName) =>
    'Skipping ${fileName.cyan} setup. This may cause issues with '
    'some Firebase services on Android in your application.';

/// Logs when the completion of a `configure` command would result in
/// modifications to these files. If the files do not require modification
/// e.g. gradle plugins are already applied, then this log is not printed.
final logPromptMakeChangesToGradleFiles = 'The files '
    '${'android/build.gradle'.cyan} & ${'android/app/build.gradle'.cyan} '
    'will be updated to apply Firebase configuration and gradle build plugins. '
    'Do you want to continue?';

/// Logs when the result of [logPromptMakeChangesToGradleFiles] is false (do not update).
const logSkippingGradleFilesUpdate =
    'Skipping applying Firebase gradle plugins for Android. This may cause '
    'issues with some Firebase services on Android in your application.';

/// A base class for all FlutterFire CLI exceptions.
abstract class FlutterFireException implements Exception {}

/// An exception that is thrown when the configure command is ran in a directory
/// that is not a Flutter project.
class FlutterAppRequiredException implements FlutterFireException {
  @override
  String toString() {
    return 'FlutterAppRequiredException: The current directory does not appear to be a Flutter application project.';
  }
}

/// An exception that is thrown when the no platforms have been selected to be
/// configured (android, ios, macos & web).
class NoFlutterPlatformsSelectedException implements FlutterFireException {
  @override
  String toString() {
    return 'NoFlutterPlatformsSelectedException: You must select at least one Flutter platform to generate your configuration for.';
  }
}

class FirebaseProjectRequiredException implements FlutterFireException {
  @override
  String toString() {
    return 'FirebaseProjectRequiredException: A Firebase project id must be specified, either via the `--project` option or a `.firebaserc` file.';
  }
}

class FirebaseProjectNotFoundException implements FlutterFireException {
  FirebaseProjectNotFoundException(this.projectId) : super();

  final String projectId;

  @override
  String toString() {
    return 'FirebaseProjectNotFoundException: Firebase project id "$projectId" could not be found on this Firebase account.';
  }
}

class FirebaseOptionsAlreadyExistsException implements FlutterFireException {
  FirebaseOptionsAlreadyExistsException(this.filePath) : super();

  final String filePath;

  @override
  String toString() {
    return 'FirebaseOptionsAlreadyExistsException: Firebase config file ${filePath.cyan} is already up to date.';
  }
}

class FirebaseAppIDAlreadyExistsException implements FlutterFireException {
  FirebaseAppIDAlreadyExistsException(this.filePath) : super();

  final String filePath;

  @override
  String toString() {
    return 'FirebaseAppIDAlreadyExistsException: Firebase app ID file ${filePath.cyan} is already up to date.';
  }
}

class PlatformDirectoryDoesNotExistException implements FlutterFireException {
  PlatformDirectoryDoesNotExistException(this.filePath) : super();

  final String filePath;

  @override
  String toString() {
    return 'PlatformDirectoryDoesNotExistException: platform directory ${filePath.cyan} does not exist. Please re-run after initializing this directory with Flutter.';
  }
}

class FlutterPlatformNotSupportedException implements FlutterFireException {
  FlutterPlatformNotSupportedException(this.platform) : super();

  final String platform;

  @override
  String toString() {
    return 'FlutterPlatformNotSupportedException: ${platform.cyan} is not currently supported by this CLI.';
  }
}

class FirebasePlatformNotSupportedException implements FlutterFireException {
  FirebasePlatformNotSupportedException(this.platform) : super();

  final String platform;

  @override
  String toString() {
    return 'FirebasePlatformNotSupportedException: ${platform.cyan} is not currently supported by Firebase.';
  }
}

class FirebaseCommandException implements FlutterFireException {
  FirebaseCommandException(this.command, this.error) : super();

  final String command;

  final String error;

  @override
  String toString() {
    return '${'FirebaseCommandException: An error occured on the Firebase CLI when attempting to run a command.\n'.red}'
        'COMMAND: ${'firebase $command'.cyan} '
        '\nERROR: $error';
  }
}
