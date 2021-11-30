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

import 'package:ansi_styles/ansi_styles.dart';

/// A base class for all FlutterFire CLI exceptions.
abstract class FlutterFireException implements Exception {}

class FlutterAppRequiredException implements FlutterFireException {
  @override
  String toString() {
    return 'FlutterAppRequiredException: The current directory does not appear to be a Flutter application project.';
  }
}

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
    return 'FirebaseOptionsAlreadyExistsException: Firebase options file ${AnsiStyles.cyan(filePath)} already exists.';
  }
}

class FlutterPlatformNotSupportedException implements FlutterFireException {
  FlutterPlatformNotSupportedException(this.platform) : super();

  final String platform;

  @override
  String toString() {
    return 'FlutterPlatformNotSupportedException: ${AnsiStyles.cyan(platform)} is not currently supported by this CLI.';
  }
}

class FirebasePlatformNotSupportedException implements FlutterFireException {
  FirebasePlatformNotSupportedException(this.platform) : super();

  final String platform;

  @override
  String toString() {
    return 'FirebasePlatformNotSupportedException: ${AnsiStyles.cyan(platform)} is not currently supported by Firebase.';
  }
}

class FirebaseCommandException implements FlutterFireException {
  FirebaseCommandException(this.command, this.error) : super();

  final String command;

  final String error;

  @override
  String toString() {
    return '${AnsiStyles.red('FirebaseCommandException: An error occured on the Firebase CLI when attempting to run a command.\n')}COMMAND: ${AnsiStyles.cyan('firebase $command')} \nERROR: $error';
  }
}
